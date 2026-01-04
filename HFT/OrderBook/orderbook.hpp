#include "helper.hpp"

class OrderBook
{
private:
    std::map<Price, PriceLevel, std::greater<Price>> bidLevels_;
    std::map<Price, PriceLevel, std::less<Price>> askLevels_;
    Price currentPrice_;

    mutable std::mutex mutex_;                          
    std::thread ordersPruneThread_;                     
    std::condition_variable shutdownConditionVariable_; 
    std::atomic<bool> shutdownFlag_{false};             

    void calcPrice();
    bool canMatch(const Order &incomingOrder) const;
    bool canMatchFully(const Order &incomingOrder) const;
    void Match(Order &incomingOrder);
    void cancelGFDOrders(bool isBids);

public:
    OrderBook(Price initial_price) : currentPrice_{initial_price} {

        // Instaniate threads for canceling GFD orders at end of day
        ordersPruneThread_ = std::thread(&OrderBook::cancelGFDOrders, this, true);
        ordersPruneThread_ = std::thread(&OrderBook::cancelGFDOrders, this, false);
    }
    ~OrderBook();
    void processOrder(Order &order);
    Price getPrice() const;
    bool isEmpty() const;
    Order getOrder(OrderId id) const;

};