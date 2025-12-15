#include <iostream>
#include <map>
#include <string>
#include <map>
#include <cmath>
#include <limits>
#include <ctime>
#include <deque>
#include <queue>
#include <stack>
#include <numeric>
#include <vector>
#include <set>
#include <unordered_map>
#include <algorithm>
#include <memory>
#include <variant>
#include <optional>
#include <tuple>
#include <format>

// This code is based off of implementation by thecodingjesus - https://www.youtube.com/watch?v=XeLWe0Cx_Lg&t=896s

// Order types
enum class OrderType
{
    GoodTillCancel,  // Limit Order that remains until canceled or filled
    FillAndKill,     // Immediate or cancel order - fills as much as possible and cancels the rest
    FillOrKill,      // Fill or kill order - must be filled entirely or canceled
    Market,          // Market order - executes immediately at the best available price
    GoodForDay       // Good for day order - remains active until the end of the trading day
};

// Order sides
enum class Side
{
    Buy,
    Sell
};

// Alias declarations for reader clarity
using Price = std::int32_t;
using Quantity = std::uint32_t;
using OrderId = std::uint64_t;

// Structure to hold level information in the order book
struct LevelInfo
{
    Price price;
    Quantity quantity;
};

using LevelInfos = std::vector<LevelInfo>;

class OrderBookLevelInfos
{
public:
    OrderBookLevelInfos(const LevelInfos &bids, const LevelInfos &asks)
        : bids_{bids},
          asks_{asks}
    {
    }

    const LevelInfos &getBids() const { return bids_; }
    const LevelInfos &getAsks() const { return asks_; }

private:
    LevelInfos bids_;
    LevelInfos asks_;
};

class Order
{
public:
    Order(OrderId id, Side side, Price price, Quantity quantity, OrderType type)
        : id_{id},
          side_{side},
          price_{price},
          initialQuantity_{quantity},
          remainingQuantity_{quantity},
          type_{type}
    {
    }

    OrderId getId() const { return id_; }
    Side getSide() const { return side_; }
    Price getPrice() const { return price_; }
    Quantity getInitialQuantity() const { return initialQuantity_; }
    Quantity getRemainingQuantity() const { return remainingQuantity_; }
    Quantity getFilledQuantity() const { return initialQuantity_ - remainingQuantity_; }
    bool isFilled() const { return remainingQuantity_ == 0; }
    OrderType getType() const { return type_; }

    void fillOrder(Quantity qty)
    {

        // Cannot fill an order more than its remaining quantity
        if (qty > remainingQuantity_)
        {
            throw std::invalid_argument("Fill quantity exceeds remaining quantity");
        }
        remainingQuantity_ -= qty;
    }

private:
    OrderId id_;
    Side side_;
    Price price_;
    Quantity initialQuantity_;
    Quantity remainingQuantity_;
    OrderType type_;
};

// Order could be stored in "order" structure or a "bid/ask" structure at the same time
using OrderPtr = std::shared_ptr<Order>;
using OrderPtrs = std::list<OrderPtr>; // Data structure to hokd list of orders at each price level

// Modify order = Cancel and replace. Requires order, price, qty, side
class OrderModify
{
public:
    OrderModify(OrderId id, Side side, Price newPrice, Quantity newQuantity)
        : id_{id},
          side_{side},
          newPrice_{newPrice},
          newQuantity_{newQuantity}
    {
    }

    OrderId getId() const { return id_; }
    Price getNewPrice() const { return newPrice_; }
    Side getSide() const { return side_; }
    Quantity getNewQuantity() const { return newQuantity_; }

    // Essentially we are making a new order given the modify details
    OrderPtr toOrderPtr(OrderType type) const
    {
        return std::make_shared<Order>(id_, side_, newPrice_, newQuantity_, type);
    }

private:
    OrderId id_;
    Price newPrice_;
    Quantity newQuantity_;
    Side side_;
};

// Match Order. Aggregation of bid and ask
struct TradeInfo
{
    OrderId orderId_;
    Price price_;
    Quantity quantity_;
};

class Trade
{
public:
    Trade(const TradeInfo &bidTrade, const TradeInfo &askTrade)
        : bidTrade_{bidTrade},
          askTrade_{askTrade}

    {
    }

    const TradeInfo &getBidTradeInfo() const { return bidTrade_; }
    const TradeInfo &getAskTradeInfo() const { return askTrade_; }

private:
    TradeInfo bidTrade_;
    TradeInfo askTrade_;
};

using Trades = std::vector<Trade>; // Handle multiple trades at once

class OrderBook
{
private:
    /**
     *  Use a map to store bid and asks
     *  Bids stored in acsending order
     *  Asks stored in descending order
     */

    struct OrderEntry
    {
        OrderPtr order_{nullptr};
        OrderPtrs::iterator location_;
    };

    std::map<Price, OrderPtrs, std::greater<Price>> bids_; // Bids in descending order
    std::map<Price, OrderPtrs, std::less<Price>> asks_;    // Asks in ascending order
    std::unordered_map<OrderId, OrderEntry> orders_;       // Map to track orders by their ID

    bool CanMatch(Side side, Price price) const
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

    Trades MatchOrders()
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

public:
    Trades AddOrder(OrderPtr order)
    {
        if (orders_.contains(order->getId()))
        {
            return {}; // Order ID already exists
        }

        if (order->getType() == OrderType::FillAndKill && !CanMatch(order->getSide(), order->getPrice()))
        {
            return {}; // FAK order cannot be added if it cannot match
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

    void CancelOrder(OrderId id)
    {
        if (!orders_.contains(id))
        {
            return; // Order ID does not exist
        }

        const auto &[order, orderIterator] = orders_.at(id);
        orders_.erase(id);

        if (order->getSide() == Side::Buy)
        {
            auto price = order->getPrice();
            auto &ordersAtPrice = bids_[price];
            ordersAtPrice.erase(orderIterator);
            if (ordersAtPrice.empty())
            {
                bids_.erase(price); // Remove price level
            }
        }
        else // Side::Sell
        {
            auto price = order->getPrice();
            auto &ordersAtPrice = asks_[price];
            ordersAtPrice.erase(orderIterator);
            if (ordersAtPrice.empty())
            {
                asks_.erase(price); // Remove price level
            }
        }
    }

    Trades ModifyOrder(OrderModify order)
    {
        if (!orders_.contains(order.getId()))
        {
            return {}; // Order ID does not exist
        }

        const auto &[existingOrder, _] = orders_.at(order.getId());
        CancelOrder(order.getId());

        // Add modified order to book
        return AddOrder(order.toOrderPtr(existingOrder->getType()));
    }

    std::size_t Size() const {
        return orders_.size();
    }

    OrderBookLevelInfos GetLevelInfos() const
    {
        LevelInfos bidLevels;
        LevelInfos askLevels;
        bidLevels.reserve(bids_.size());
        askLevels.reserve(asks_.size());

        auto CreateLevelInfos = [](const auto &orderMap, LevelInfos &levelInfos) {
            return LevelInfo{ price, std::accumulate(
                                        orders.begin(),
                                        orders.end(),
                                        0u,
                                        [](std::size_t runningSum, const OrderPtr &order) {
                                            return runningSum + order->getRemainingQuantity();
                                        }) };
        };

        for(const auto& [price, ordersAtPrice] : bids_) {
            bidLevels.push_back(CreateLevelInfos(bids_, bidLevels));
        }
        for(const auto& [price, ordersAtPrice] : asks_) {
            askLevels.push_back(CreateLevelInfos(asks_, askLevels));
        }

        return OrderBookLevelInfos{bidLevels, askLevels};

    }
};