#include "helper.hpp"

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

    struct LevelData
    {
        Quantity quantity_{};
        Quantity count_{};

        enum class Action
        {
            Add,
            Remove,
            Match,
            PartialMatch
        };
    };

    std::unordered_map<Price, LevelData> data_;            // Level data for quick access
    std::map<Price, OrderPtrs, std::greater<Price>> bids_; // Bids in descending order
    std::map<Price, OrderPtrs, std::less<Price>> asks_;    // Asks in ascending order
    std::unordered_map<OrderId, OrderEntry> orders_;       // Map to track orders by their ID

    // Threading allows us to prune GTD orders while processing orders
    mutable std::mutex mutex_;                          // Mutex for thread safety
    std::thread ordersPruneThread_;                     // Thread for pruning old orders
    std::condition_variable shutdownConditionVariable_; // Condition variable for shutdown signal
    std::atomic<bool> shutdownFlag_{false};             // Atomic flag to signal shutdown

    bool CanMatch(Side side, Price price) const;
    Trades MatchOrders();
    void CancelOrderInternal(OrderId id);
    void CancelOrders(OrderIds orderIds);
    void OnOrderCancelled(OrderPtr order);
    void PruneGoodForDayOrders();
    void OnOrderAdded(OrderPtr order);
    void OnOrderMatched(OrderPtr order, Quantity filledQuantity, bool isFullyFilled);
    void UpdateLevelData(Price price, Quantity quantity, LevelData::Action action);
    bool CanFullyFIll(Side side, Price price, Quantity quantity) const;

public:

    OrderBook();
    OrderBook(const OrderBook &) = delete;
    void operator=(const OrderBook &) = delete;
    OrderBook( OrderBook &&) = delete;
    void operator=( OrderBook &&) = delete;
    ~OrderBook();



    Trades AddOrder(OrderPtr order);
    void CancelOrder(OrderId id);
    Trades ModifyOrder(OrderModify order);
    std::size_t Size() const
    {
        return orders_.size();
    }
    OrderBookLevelInfos GetLevelInfos() const;
};