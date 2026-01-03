#include "orderbook.hpp"

enum class SimulationMode{
    Normal,
    Reactive
};

struct Report{
    Price currentPrice;
    Quantity totalBidQuantity;
    Quantity totalAskQuantity;
    size_t totalBidLevels;
    size_t totalAskLevels;
};

class MarketSimulator
{
private:
    OrderBook orderBook_;

    void GenerateOrders();
    void SendOrdersToOrderBook();
    void UpdateMarketState();

public:

    MarketSimulator(Price initialPrice, SimulationMode simMode);
    Report getReport() const;
};