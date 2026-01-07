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
    double spread;
    Quantity totalBidQuantity;
    Quantity totalAskQuantity;
    size_t totalBidLevels;
    size_t totalAskLevels;
    Quantity bestBidQuantity;
    Quantity bestAskQuantity;
};

class MarketSimulator
{
private:
    OrderBook orderBook_;
    std::queue<Order> outgoingOrders_;
    std::queue<Order> fpgaOrders_;
    char* outputStream_;
    char* fpgaStream_;
    bool beginRun_{false};
    SimulationMode simMode_;
    MarketState marketState_;
    SimulationParamaters simParameters_;
    std::string reportFile_;
    Report marketReport_;

    void GenerateOrders();
    void ReceiveOrders();
    void PopulateOrderBook();
    void SendOrders();
    void UpdateMarketState();

    void EncodeOrders();
    void DecodeOrders();
    time_t PoissonNextArrival();
    Price calcOrderPrice();
    Quantity calcOrderQuantity();
    void createAdd();
    void createModifyOrCancel();

public:

    MarketSimulator(Price initialPrice, SimulationMode simMode, SimulationParamaters simParameters, std::string reportFile);
    void updateReport();
    void writeReport() const;
};