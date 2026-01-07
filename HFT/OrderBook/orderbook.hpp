#include "helper.hpp"

class OrderBook
{
private:
    std::map<Price, PriceLevel, std::greater<Price>> bidLevels_;
    std::map<Price, PriceLevel, std::less<Price>> askLevels_;
    Price currentPrice_;           

    void calcPrice();
    bool canMatch(const Order &incomingOrder) const;
    bool canMatchFully(const Order &incomingOrder) const;
    void Match(Order &incomingOrder);
    void cancelGFDOrders(bool isBids);

public:
    OrderBook(Price initial_price) : currentPrice_{initial_price} {
        // Instaniate threads for canceling GFD orders at end of day
    }
    ~OrderBook();
    void processOrder(Order &order);
    Price getPrice() const;
    int getLevelQuantity(Side side, Price price) const;
    Price getBestSidePrice(Side side) const;
    Quantity getSideQuantity(Side side) const;
    bool isEmpty() const;
    Order getOrder(OrderId id) const;
    double getSpread() const;

};