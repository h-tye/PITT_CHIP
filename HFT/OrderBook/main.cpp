#include "main.hpp"

// CAN MATCH
bool OrderBook::CanMatch(Side side, Price price) const
{
    if (side == Side::Buy)
    {
        // If asks exist and price is >= best ask price, then we can match
        return !asks_.empty() && price >= asks_.begin()->first;
    }
    else // Side::Sell
    {
        return !bids_.empty() && price <= bids_.begin()->first;
    }
}

// MATCH ORDERS
Trades OrderBook::MatchOrders()
{

    Trades trades;
    trades.reserve(orders_.size());

    while (true)
    {
        if (bids_.empty() || asks_.empty())
        {
            // No more possible matches
            break;
        }

        auto &[bidPrice, bids] = *bids_.begin();
        auto &[askPrice, asks] = *asks_.begin();

        if (bidPrice < askPrice)
        {
            // Can't match
            break;
        }

        while (bids.size() && asks.size())
        {
            auto &bid = bids.front();
            auto &ask = asks.front();

            // Amount we can trade
            Quantity tradeQty = std::min(bid->getRemainingQuantity(), ask->getRemainingQuantity());

            bid->fillOrder(tradeQty);
            ask->fillOrder(tradeQty);

            if (bid->isFilled())
            {
                // Remove from order book b/c filled
                orders_.erase(bid->getId());
                bids.pop_front();
            }

            if (ask->isFilled())
            {
                orders_.erase(ask->getId());
                asks.pop_front();
            }

            if (bids.empty())
            {
                bids_.erase(bidPrice);
            }

            if (asks.empty())
            {
                asks_.erase(askPrice);
            }

            // Generate a trade
            trades.push_back(Trade(
                TradeInfo{bid->getId(), bidPrice, tradeQty},
                TradeInfo{ask->getId(), askPrice, tradeQty}));
        }

        // If Fill and Kill orders remain at the top of the book, remove them
        if (!bids_.empty())
        {
            auto &[_, bids] = *bids_.begin();
            auto &order = bids.front();

            if (order->getType() == OrderType::FillAndKill && order->getRemainingQuantity() > 0)
            {
                // Remove FAK order if not filled
                orders_.erase(order->getId());
                bids.pop_front();

                if (bids.empty())
                {
                    bids_.erase(bidPrice);
                }
            }
        }
        if (!asks_.empty())
        {
            auto &[_, asks] = *asks_.begin();
            auto &order = asks.front();

            if (order->getType() == OrderType::FillAndKill && order->getRemainingQuantity() > 0)
            {
                orders_.erase(order->getId());
                bids.pop_front();

                if (bids.empty())
                {
                    bids_.erase(bidPrice);
                }
            }
        }

        return trades;
    }
}

// ADD ORDERS
Trades OrderBook::AddOrder(OrderPtr order)
{

    if (orders_.find(order->getId()) != orders_.end())
    {
        return {}; // Order ID already exists
    }

    if (order->getType() == OrderType::FillAndKill && !CanMatch(order->getSide(), order->getPrice()))
    {
        return {}; // FAK order cannot be added if it cannot match
    }

    if (order->getType() == OrderType::Market)
    {
        // Market order - set price to extreme value based on side
        if (order->getSide() == Side::Buy && !asks_.empty())
        {
            const auto &[worstAsk, _] = *asks_.begin();
            order->ToGoodTillCancel(worstAsk); // Convert to GTC at worst ask price
        }
        else if (order->getSide() == Side::Sell && !bids_.empty())
        {
            const auto &[bestBid, _] = *bids_.begin();
            order->ToGoodTillCancel(bestBid);
        }
        else
        {
            // No orders to match against, cannot add market order
            return {};
        }
    }

    // Add order to book
    OrderPtrs::iterator location;
    if (order->getSide() == Side::Buy)
    {
        auto &orders = bids_[order->getPrice()];
        orders.push_back(order);
        location = std::prev(orders.end());
    }
    else // Side::Sell
    {
        auto &orders = asks_[order->getPrice()];
        orders.push_back(order);
        location = std::prev(orders.end());
    }

    // Track order by ID
    orders_.insert({order->getId(), OrderEntry{order, location}});

    return MatchOrders();
}

// CANCEL ORDER
void OrderBook::CancelOrder(OrderId id)
{
    std::scoped_lock<std::mutex> lock(mutex_);
    CancelOrderInternal(id);
}

// CANCEL ORDERS
void OrderBook::CancelOrders(OrderIds orderIds)
{

    std::scoped_lock<std::mutex> lock(mutex_);

    for (const auto &orderId : orderIds)
    {
        CancelOrderInternal(orderId);
    }
}

// CANCEL ORDER INTERNAL
void OrderBook::CancelOrderInternal(OrderId id)
{

    if (orders_.find(id) == orders_.end())
    {
        return; // Order ID does not exist
    }

    const auto [order, iterator] = orders_.at(id);
    orders_.erase(id);

    if (order->getSide() == Side::Sell)
    {
        auto price = order->getPrice();
        auto &ordersAtPrice = asks_[price];
        ordersAtPrice.erase(iterator);
        if (ordersAtPrice.empty())
        {
            asks_.erase(price); // Remove price level
        }
    }
    else // Side::Buy
    {
        auto price = order->getPrice();
        auto &ordersAtPrice = bids_[price];
        ordersAtPrice.erase(iterator);
        if (ordersAtPrice.empty())
        {
            bids_.erase(price); // Remove price level
        }
    }

    OnOrderCancelled(order);
}

// ON ORDER CANCELLED
void OrderBook::OnOrderCancelled(OrderPtr order)
{
    UpdateLevelData(order->getPrice(), order->getRemainingQuantity(), LevelData::Action::Remove);
}

// ON ORDER ADDED
void OrderBook::OnOrderAdded(OrderPtr order)
{
    UpdateLevelData(order->getPrice(), order->getRemainingQuantity(), LevelData::Action::Add);
}

// ON ORDER MATCHED
void OrderBook::OnOrderMatched(OrderPtr order, Quantity filledQuantity, bool isFullyFilled)
{
    UpdateLevelData(order->getPrice(), filledQuantity, isFullyFilled ? LevelData::Action::Match : LevelData::Action::PartialMatch);
}

// UPDATE LEVEL DATA
void OrderBook::UpdateLevelData(Price price, Quantity quantity, LevelData::Action action)
{
    auto &data = data_[price];

    data.count_ += action == LevelData::Action::Remove ? -1 : action == LevelData::Action::Add ? 1
                                                                                               : 0;
    if (action == LevelData::Action::Add || action == LevelData::Action::Match)
    {
        data.quantity_ -= quantity;
    }
    else
    {
        data.quantity_ += quantity;
    }

    if (data.count_ == 0)
    {
        data_.erase(price); // Remove level data if no orders remain
    }
}

// CAN FULLY FILL
bool OrderBook::CanFullyFIll(Side side, Price price, Quantity quantity) const
{

    if (!CanMatch(side, price))
    {
        return false; // Cannot match at all
    }

    std::optional<Price> threshold;

    if (side == Side::Buy)
    {
        const auto [askPrice, _] = *asks_.begin();
        threshold = askPrice;
    }
    else
    {
        const auto [bidPrice, _] = *bids_.begin();
        threshold = bidPrice;
    }

    for (const auto &[levelPrice, levelData] : data_)
    {

        if (threshold.has_value() && ((side == Side::Buy && levelPrice > threshold.value()) || (side == Side::Sell && levelPrice < threshold.value())))
        {
            continue;
        }

        if ((side == Side::Buy && levelPrice > price) || (side == Side::Sell && levelPrice < price))
        {
            continue;
        }

        if (quantity <= levelData.quantity_)
        {
            return true; // Can fully fill
        }

        quantity -= levelData.quantity_;
    }

    return false;
}

// MODIFY ORDER
Trades OrderBook::ModifyOrder(OrderModify order)
{
    if (orders_.find(order.getId()) == orders_.end())
    {
        return {}; // Order ID does not exist
    }

    const auto &[existingOrder, _] = orders_.at(order.getId());
    CancelOrder(order.getId());

    // Add modified order to book
    return AddOrder(order.toOrderPtr(existingOrder->getType()));
}

// GET LEVEL INFO
OrderBookLevelInfos OrderBook::GetLevelInfos() const
{
    LevelInfos bidLevels;
    LevelInfos askLevels;
    bidLevels.reserve(bids_.size());
    askLevels.reserve(asks_.size());

    auto CreateLevelInfos = [](Price price, const OrderPtrs &orders)
    {
        return LevelInfo{price, std::accumulate(
                                    orders.begin(),
                                    orders.end(),
                                    (Quantity)0,
                                    [](Quantity runningSum, const OrderPtr &order)
                                    {
                                        return runningSum + order->getRemainingQuantity();
                                    })};
    };

    for (const auto &[price, ordersAtPrice] : bids_)
    {
        bidLevels.push_back(CreateLevelInfos(price, ordersAtPrice));
    }
    for (const auto &[price, ordersAtPrice] : asks_)
    {
        askLevels.push_back(CreateLevelInfos(price, ordersAtPrice));
    }

    return OrderBookLevelInfos{bidLevels, askLevels};
}

// PRUNE GOOD FOR DAY ORDERS
void OrderBook::PruneGoodForDayOrders()
{
    using namespace std::chrono_literals;
    const auto end = 16h; // Assuming trading day ends at 4 PM

    while (true)
    {
        const auto now = std::chrono::system_clock::now();
        const auto now_c = std::chrono::system_clock::to_time_t(now);
        std::tm now_parts;
        localtime_s(&now_parts, &now_c);

        if (now_parts.tm_hour >= end.count())
        {
            now_parts.tm_mday += 1; // Move to next day
        }

        now_parts.tm_hour = end.count(); // Set wakeup time to 4 PM
        now_parts.tm_min = 0;
        now_parts.tm_sec = 0;

        auto next = std::chrono::system_clock::from_time_t(mktime(&now_parts));
        auto till = next - now + std::chrono::milliseconds(100); // Add small buffer

        {
            std::unique_lock<std::mutex> lock(mutex_);

            // If ordebook has shutten down or is shutting down,exit
            if (shutdownFlag_.load(std::memory_order_acquire) || shutdownConditionVariable_.wait_for(lock, till) == std::cv_status::no_timeout)
                return;
        }

        OrderIds orderIds; // Store order IDs to cancel

        {
            std::scoped_lock<std::mutex> lock(mutex_);
            for (const auto &[orderId, orderEntry] : orders_)
            {
                const auto &order = orderEntry.order_;

                if (order->getType() == OrderType::GoodForDay)
                {
                    orderIds.push_back(orderId);
                }
            }
        }

        CancelOrders(orderIds);
    }
}

OrderBook::OrderBook() : ordersPruneThread_([this]
                                            { PruneGoodForDayOrders(); })
{
}

OrderBook::~OrderBook()
{
    shutdownFlag_.store(true, std::memory_order_release);
    shutdownConditionVariable_.notify_all();
    if (ordersPruneThread_.joinable())
    {
        ordersPruneThread_.join();
    }
}
