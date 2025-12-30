#include "helper.hpp"

class OrderBook
{
private:
    std::map<Price, PriceLevel, std::greater<Price>> bidLevels_;
    std::map<Price, PriceLevel, std::less<Price>> askLevels_;
    Price currentPrice_;

    void calcPrice();
    bool canMatch(const Order &incomingOrder) const;
    void Match(Order &incomingOrder);

public:
    OrderBook() : currentPrice_{0} {}
    void processOrder(Order &order);
    Price getPrice() const;
};