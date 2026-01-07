#include "simulator.hpp"

MarketSimulator::MarketSimulator(Price initialPrice, SimulationMode simMode, SimulationParamaters simParameters, std::string reportFile)
    : orderBook_(initialPrice), simMode_(simMode), simParameters_(simParameters), reportFile_(reportFile)
{

    // Initialize simulation
    GenerateOrders();
    PopulateOrderBook();
    SendOrders();

    // Once all parties are set up, begin the run
    if (beginRun_)
    {
        GenerateOrders(); // All of these should run indefinitely in their own threads
        PopulateOrderBook();
        SendOrders();
        ReceiveOrders();
        UpdateMarketState();
    }
}

void MarketSimulator::GenerateOrders()
{

    if (!beginRun_)
    {
        // Initial population of order book
        for (int i = 0; i < 1000; ++i)
        {
            createAdd();
        }
        beginRun_ = true;
        return;
    }

    if (simMode_ == SimulationMode::Normal)
    {

        // Generate random orders
        srand(time(NULL));
        while (true)
        {
            if (rand() % 2 && !orderBook_.isEmpty())
            {
                createModifyOrCancel();
            }
            else
            {
                createAdd();
            }
        }
    }
    else if (simMode_ == SimulationMode::Reactive)
    {
        // Generate orders based on market state
    }
}

void MarketSimulator::UpdateMarketState()
{
    switch (simMode_)
    {
    case SimulationMode::Normal:
        break;
    case SimulationMode::Reactive:
        // Use OrderBook as well as external orders to determine market state
        break;
    default:
        // Handle unexpected mode
    }
}

/* Thread both parts of this method to run concurrently */
void MarketSimulator::PopulateOrderBook()
{
    time_t nextArrival = PoissonNextArrival();
    time_t currentTime = time(nullptr);
    while (true)
    {
        if (difftime(time(nullptr), currentTime) >= nextArrival)
        {
            if (!outgoingOrders_.empty())
            {
                Order order = outgoingOrders_.front();
                outgoingOrders_.pop();
                orderBook_.processOrder(order);
            }
            currentTime = time(nullptr);
            nextArrival = PoissonNextArrival();
        }
    }

    while (true)
    {
        if (!fpgaOrders_.empty())
        {
            Order order = fpgaOrders_.front();
            fpgaOrders_.pop();
            orderBook_.processOrder(order);
        }
    }
}

time_t MarketSimulator::PoissonNextArrival()
{
    std::default_random_engine generator(static_cast<unsigned>(time(0)));
    std::poisson_distribution<int> distribution(simParameters_.OrderFrequency * 1000);

    return static_cast<time_t>(distribution(generator));
}

void MarketSimulator::createAdd()
{
    Side side = (rand() % 2 == 0) ? Side::Buy : Side::Sell;
    OrderType type = (rand() % 2 == 0) ? OrderType::Market : OrderType::GoodTillCancel;
    OrderId orderId = static_cast<std::uint64_t>(rand());
    Quantity quantity = calcOrderQuantity();
    if (type == OrderType::GoodTillCancel)
    {
        Price price = calcOrderPrice();
        switch (rand() % 4)
        {
        case 0:
            type = OrderType::GoodTillCancel;
            break;
        case 1:
            type = OrderType::FillAndKill;
            break;
        case 2:
            type = OrderType::FillOrKill;
            break;
        case 3:
            type = OrderType::GoodForDay;
            break;
        }
        Order order(orderId, side, price, quantity, type, Action::Add);
        outgoingOrders_.push(order);
    }
    else
    {
        Order order(orderId, side, quantity, type);
        outgoingOrders_.push(order);
    }
}

void MarketSimulator::createModifyOrCancel()
{
    OrderId existingOrderId = static_cast<std::uint64_t>(rand());
    Order existingOrder = orderBook_.getOrder(existingOrderId);

    if (rand() % 2 == 0)
    {
        // Modify order
        Quantity newQuantity = calcOrderQuantity();
        Price newPrice = calcOrderPrice();
        Order modifiedOrder(existingOrder.getId(), existingOrder.getSide(), newPrice, newQuantity, existingOrder.getType(), Action::Modify);
        outgoingOrders_.push(modifiedOrder);
    }
    else
    {
        // Cancel order
        Order cancelOrder(existingOrder.getId(), existingOrder.getSide(), existingOrder.getPrice(), existingOrder.getRemainingQuantity(), existingOrder.getType(), Action::Cancel);
        outgoingOrders_.push(cancelOrder);
    }
}

Price MarketSimulator::calcOrderPrice()
{
    Price basePrice = orderBook_.getPrice();
    std::default_random_engine generator(static_cast<unsigned>(time(0)));
    std::normal_distribution<double> distribution(0.0, TICK_SIZE * simParameters_.PriceVolatility);

    double priceFluctuation = distribution(generator);
    return static_cast<Price>(basePrice + priceFluctuation);
}

Quantity MarketSimulator::calcOrderQuantity()
{
    std::default_random_engine generator(static_cast<unsigned>(time(0)));
    std::uniform_int_distribution<int> distribution(1, simParameters_.OrderVolume * 100); // Max volume scaled

    return static_cast<Quantity>(distribution(generator)) / orderBook_.getPrice(); // High price usually correlates to lower quantity
}

void MarketSimulator::updateReport()
{
    marketReport_.currentPrice = orderBook_.getPrice();
    marketReport_.spread = orderBook_.getSpread();
    marketReport_.bestBidQuantity = orderBook_.getLevelQuantity(Side::Buy, orderBook_.getBestSidePrice(Side::Buy));
    marketReport_.bestAskQuantity = orderBook_.getLevelQuantity(Side::Sell, orderBook_.getBestSidePrice(Side::Sell));
    marketReport_.totalBidQuantity = orderBook_.getSideQuantity(Side::Buy);
    marketReport_.totalAskQuantity = orderBook_.getSideQuantity(Side::Sell);
}

void MarketSimulator::writeReport() const
{
    std::ofstream reportStream(reportFile_, std::ios::app);
    if (reportStream.is_open())
    {
        reportStream << "Current Price: " << marketReport_.currentPrice << "\n";
        reportStream << "Spread: " << marketReport_.spread << "\n";
        reportStream << "Total Bid Quantity: " << marketReport_.totalBidQuantity << "\n";
        reportStream << "Total Ask Quantity: " << marketReport_.totalAskQuantity << "\n";
        reportStream << "Total Bid Levels: " << marketReport_.totalBidLevels << "\n";
        reportStream << "Total Ask Levels: " << marketReport_.totalAskLevels << "\n";
        reportStream << "Best Bid Quantity: " << marketReport_.bestBidQuantity << "\n";
        reportStream << "Best Ask Quantity: " << marketReport_.bestAskQuantity << "\n";
        reportStream << "----------------------------------------\n";
        reportStream.close();
    }
}