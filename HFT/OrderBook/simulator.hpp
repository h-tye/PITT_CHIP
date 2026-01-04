#include "orderbook.hpp"

#define TICK_SIZE 0.01

struct SimulationParamaters{  // Ranges 1 - 5
    int OrderFrequency;    
    int OrderVolume;    
    int PriceVolatility;    
};

enum class SimulationMode{
    Normal,
    Reactive
};

enum class MarketState{
    Bull,   // Buying market
    Bear,   // Selling market
    Stable
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
    SimulationMode simMode_;
    std::queue<Order> outputStream_;
    std::queue<Order> inputStream_;
    MarketState marketState_;
    SimulationParamaters simParameters_;

    void GenerateOrders();
    void ReceiveOrders();
    void PopulateOrderBook();
    void UpdateMarketState();

    Price calcOrderPrice();
    Quantity calcOrderQuantity();
    void createAdd();
    void createModifyOrCancel();

public:

    MarketSimulator(Price initialPrice, SimulationMode simMode, SimulationParamaters simParameters);
    Report getReport() const;
};