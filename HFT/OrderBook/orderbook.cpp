#include "orderbook.hpp"

void OrderBook::calcPrice()
{
    // Simple price calculation: midpoint of best bid and ask
    if (!bidLevels_.empty() && !askLevels_.empty())
    {
        Price bestBid = bidLevels_.begin()->first;
        Price bestAsk = askLevels_.begin()->first;
        currentPrice_ = (bestBid + bestAsk) / 2;
    }
    else if (!bidLevels_.empty())
    {
        currentPrice_ = bidLevels_.begin()->first;
    }
    else if (!askLevels_.empty())
    {
        currentPrice_ = askLevels_.begin()->first;
    }
    else
    {
        currentPrice_ = 0; // No price available
    }
}

Price OrderBook::getPrice() const
{
    return currentPrice_;
}

bool OrderBook::canMatch(const Order &incomingOrder) const
{
    if (incomingOrder.getSide() == Side::Buy)
    {
        // Buy order can match if there's at least one ask level at or below the order price
        if (askLevels_.empty())
            return false;
        Price bestAsk = askLevels_.begin()->first;
        return incomingOrder.getType() == OrderType::Market || incomingOrder.getPrice() >= bestAsk;
    }
    else
    {
        // Sell order can match if there's at least one bid level at or above the order price
        if (bidLevels_.empty())
            return false;
        Price bestBid = bidLevels_.begin()->first;
        return incomingOrder.getType() == OrderType::Market || incomingOrder.getPrice() <= bestBid;
    }
}

bool OrderBook::canMatchFully(const Order &incomingOrder) const
{
    Quantity totalAvailable = 0;
    if (incomingOrder.getSide() == Side::Buy)
    {
        for (const auto &askLevel : askLevels_)
        {
            if (incomingOrder.getType() != OrderType::Market && askLevel.first > incomingOrder.getPrice())
                break;
            totalAvailable += askLevel.second.getTotalQuantity();
            if (totalAvailable >= incomingOrder.getRemainingQuantity())
                return true;
        }
    }
    else
    {
        for (const auto &bidLevel : bidLevels_)
        {
            if (incomingOrder.getType() != OrderType::Market && bidLevel.first < incomingOrder.getPrice())
                break;
            totalAvailable += bidLevel.second.getTotalQuantity();
            if (totalAvailable >= incomingOrder.getRemainingQuantity())
                return true;
        }
    }
    return false;
}

void OrderBook::Match(Order &incomingOrder)
{
    if (incomingOrder.getSide() == Side::Buy)
    {
        // Match against ask levels
        auto askIt = askLevels_.begin();
        while (askIt != askLevels_.end() && !incomingOrder.isFilled())
        {
            PriceLevel &level = askIt->second;
            std::map<OrderId, Order> &orders = level.getOrders();
            for (auto orderIt = orders.begin(); orderIt != orders.end() && !incomingOrder.isFilled();)
            {
                Order &bookOrder = orderIt->second;
                Quantity matchQty = std::min(incomingOrder.getRemainingQuantity(), bookOrder.getRemainingQuantity());
                incomingOrder.fillOrder(matchQty);
                bookOrder.fillOrder(matchQty);

                if (bookOrder.isFilled())
                {
                    orderIt = orders.erase(orderIt);
                    level.removeOrder(bookOrder);
                }
                else
                {
                    ++orderIt;
                }
            }

            if (level.getTotalQuantity() == 0)
            {
                askIt = askLevels_.erase(askIt);
            }
            else
            {
                ++askIt;
            }
            
        }
    }
    else
    {
        // Match against bid levels
        auto bidIt = bidLevels_.begin();
        while (bidIt != bidLevels_.end() && !incomingOrder.isFilled())
        {
            PriceLevel &level = bidIt->second;
            std::map<OrderId, Order> &orders = level.getOrders();
            for (auto orderIt = orders.begin(); orderIt != orders.end() && !incomingOrder.isFilled();)
            {
                Order &bookOrder = orderIt->second;
                Quantity matchQty = std::min(incomingOrder.getRemainingQuantity(), bookOrder.getRemainingQuantity());
                incomingOrder.fillOrder(matchQty);
                bookOrder.fillOrder(matchQty);

                if (bookOrder.isFilled())
                {
                    orderIt = orders.erase(orderIt);
                    level.removeOrder(bookOrder);
                }
                else
                {
                    ++orderIt;
                }
            }

            if (level.getTotalQuantity() == 0)
            {
                bidIt = bidLevels_.erase(bidIt);
            }
            else
            {
                ++bidIt;
            }
        }
    }

    // Recalculate price after matching
    calcPrice();
}

// Process order based on type
void OrderBook::processOrder(Order &order){
    
    switch(order.getType()){
        case OrderType::Market:
            if(canMatch(order)){
                std::lock_guard<std::mutex> lock(mutex_);
                Match(order);
            }
            break;
        case OrderType::GoodTillCancel:
        case OrderType::GoodForDay:
            if(canMatch(order)){
                std::lock_guard<std::mutex> lock(mutex_);
                Match(order);
            }
            if(!order.isFilled()){
                
                PriceLevel* levelPtr = nullptr;
                if(order.getSide() == Side::Buy){
                    auto it = bidLevels_.find(order.getPrice());
                    if(it == bidLevels_.end()){
                        std::lock_guard<std::mutex> lock(mutex_);
                        auto res = bidLevels_.emplace(order.getPrice(), PriceLevel(order.getPrice()));
                        levelPtr = &(res.first->second);
                    } else {
                        levelPtr = &(it->second);
                    }
                } else {
                    auto it = askLevels_.find(order.getPrice());
                    if(it == askLevels_.end()){
                        std::lock_guard<std::mutex> lock(mutex_);
                        auto res = askLevels_.emplace(order.getPrice(), PriceLevel(order.getPrice()));
                        levelPtr = &(res.first->second);
                    } else {
                        levelPtr = &(it->second);
                    }
                }

                std::lock_guard<std::mutex> lock(mutex_);
                levelPtr->addOrder(order);
                // Recalculate price after adding order
                calcPrice();
            }
            break;
        case OrderType::FillAndKill:
            if(canMatch(order)){
                std::lock_guard<std::mutex> lock(mutex_);
                Match(order);
            }
            // Any unfilled portion is canceled (do nothing)
            break;
        case OrderType::FillOrKill:
            
            if(canMatchFully(order)){
                Match(order);
            }
            // If not fully filled, entire order is canceled (do nothing)
            break;
    }

}

void OrderBook::cancelGFDOrders(bool isBids)
{

    if(isBids){

        while(true){

            // Get time
            auto now = std::chrono::system_clock::now();
            std::time_t now_c = std::chrono::system_clock::to_time_t(now);
            std::tm now_tm;
            localtime_s(&now_tm, &now_c);

            if(now_tm.tm_hour == 16 && now_tm.tm_min == 0 && now_tm.tm_sec == 0){

                for(auto &bidLevelPair : bidLevels_)
                {
                    PriceLevel &level = bidLevelPair.second;
                    std::map<OrderId, Order> &orders = level.getOrders();
                    for (auto it = orders.begin(); it != orders.end();)
                    {
                        if (it->second.getType() == OrderType::GoodTillCancel)
                        {
                            // Lock mutex while modifying shared data
                            std::lock_guard<std::mutex> lock(mutex_);
                            it = orders.erase(it);
                            level.removeOrder(it->second);
                        }
                        else
                        {
                            ++it;
                        }
                    }
                }
            }
        }

    }
    else{

        while(true){

            // Get time
            auto now = std::chrono::system_clock::now();
            std::time_t now_c = std::chrono::system_clock::to_time_t(now);
            std::tm now_tm;
            localtime_s(&now_tm, &now_c);

            if(now_tm.tm_hour == 16 && now_tm.tm_min == 0 && now_tm.tm_sec == 0){
                
                for(auto &askLevelPair : askLevels_)
                {
                    PriceLevel &level = askLevelPair.second;
                    std::map<OrderId, Order> &orders = level.getOrders();
                    for (auto it = orders.begin(); it != orders.end();)
                    {
                        if (it->second.getType() == OrderType::GoodTillCancel)
                        {
                            // Lock mutex while modifying shared data
                            std::lock_guard<std::mutex> lock(mutex_);
                            it = orders.erase(it);
                            level.removeOrder(it->second);
                        }
                        else
                        {
                            ++it;
                        }
                    }
                }
            }
        }
    }
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

bool OrderBook::isEmpty() const
{
    std::lock_guard<std::mutex> lock(mutex_);
    return bidLevels_.empty() && askLevels_.empty();
}

Order OrderBook::getOrder(OrderId id) const
{
    std::lock_guard<std::mutex> lock(mutex_);

    // Search in bid levels
    for (const auto &bidLevelPair : bidLevels_)
    {
        const PriceLevel &level = bidLevelPair.second;
        const auto &orders = level.getOrders();
        auto it = orders.find(id);
        if (it != orders.end())
        {
            return it->second;
        }
    }

    // Search in ask levels
    for (const auto &askLevelPair : askLevels_)
    {
        const PriceLevel &level = askLevelPair.second;
        const auto &orders = level.getOrders();
        auto it = orders.find(id);
        if (it != orders.end())
        {
            return it->second;
        }
    }

    throw std::invalid_argument("Order ID not found");
}