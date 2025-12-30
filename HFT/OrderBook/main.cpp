#include "main.hpp"

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
                Match(order);
            }
            break;
        case OrderType::GoodTillCancel:
            if(canMatch(order)){
                Match(order);
            }
            if(!order.isFilled()){
                
                PriceLevel* levelPtr = nullptr;
                if(order.getSide() == Side::Buy){
                    auto it = bidLevels_.find(order.getPrice());
                    if(it == bidLevels_.end()){
                        auto res = bidLevels_.emplace(order.getPrice(), PriceLevel(order.getPrice()));
                        levelPtr = &(res.first->second);
                    } else {
                        levelPtr = &(it->second);
                    }
                } else {
                    auto it = askLevels_.find(order.getPrice());
                    if(it == askLevels_.end()){
                        auto res = askLevels_.emplace(order.getPrice(), PriceLevel(order.getPrice()));
                        levelPtr = &(res.first->second);
                    } else {
                        levelPtr = &(it->second);
                    }
                }
                levelPtr->addOrder(order);
                // Recalculate price after adding order
                calcPrice();
            }
            break;
        case OrderType::FillAndKill:
            if(canMatch(order)){
                Match(order);
            }
            // Any unfilled portion is canceled (do nothing)
            break;
    }
    

}