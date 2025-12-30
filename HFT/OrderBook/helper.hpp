#include <iostream>
#include <map>
#include <string>
#include <map>
#include <cmath>
#include <limits>
#include <ctime>
#include <deque>
#include <queue>
#include <stack>
#include <numeric>
#include <vector>
#include <set>
#include <unordered_map>
#include <algorithm>
#include <memory>
#include <variant>
#include <optional>
#include <tuple>
#include <format>
#include <list>
#include <mutex>
#include <thread>
#include <chrono>

// This code is based off of implementation by thecodingjesus - https://www.youtube.com/watch?v=XeLWe0Cx_Lg&t=896s

// Order types
enum class OrderType
{
    GoodTillCancel, // Limit Order that remains until canceled or filled
    FillAndKill,    // Immediate or cancel order - fills as much as possible and cancels the rest
    FillOrKill,     // Fill or kill order - must be filled entirely or canceled
    Market,         // Market order - executes immediately at the best available price
    GoodForDay      // Good for day order - remains active until the end of the trading day
};

// Order sides
enum class Side
{
    Buy,
    Sell
};

struct Constants
{
    static const Price INVALID_PRICE = -1;
};

// Structure to hold level information in the order book
struct LevelInfo
{
    Price price;
    Quantity quantity;
};

class OrderBookLevelInfos
{
public:
    OrderBookLevelInfos(const LevelInfos &bids, const LevelInfos &asks)
        : bids_{bids},
          asks_{asks}
    {
    }

    const LevelInfos &getBids() const { return bids_; }
    const LevelInfos &getAsks() const { return asks_; }

private:
    LevelInfos bids_;
    LevelInfos asks_;
};

class Order
{
public:
    // Constructor for market order, we don't care about price
    Order(OrderId id, Side side, Quantity quantity, OrderType type)
        : id_{id},
          side_{side},
          price_{Constants::INVALID_PRICE},
          initialQuantity_{quantity},
          remainingQuantity_{quantity},
          type_{type}
    {
    }

    Order(OrderId id, Side side, Price price, Quantity quantity, OrderType type)
        : id_{id},
          side_{side},
          price_{price},
          initialQuantity_{quantity},
          remainingQuantity_{quantity},
          type_{type}
    {
    }

    OrderId getId() const { return id_; }
    Side getSide() const { return side_; }
    Price getPrice() const { return price_; }
    Quantity getInitialQuantity() const { return initialQuantity_; }
    Quantity getRemainingQuantity() const { return remainingQuantity_; }
    Quantity getFilledQuantity() const { return initialQuantity_ - remainingQuantity_; }
    bool isFilled() const { return remainingQuantity_ == 0; }
    OrderType getType() const { return type_; }

    void fillOrder(Quantity qty)
    {

        // Cannot fill an order more than its remaining quantity
        if (qty > remainingQuantity_)
        {
            throw std::invalid_argument("Fill quantity exceeds remaining quantity");
        }
        remainingQuantity_ -= qty;
    }

    void ToGoodTillCancel(Price price)
    {
        price_ = price;
        type_ = OrderType::GoodTillCancel;
    }

private:
    OrderId id_;
    Side side_;
    Price price_;
    Quantity initialQuantity_;
    Quantity remainingQuantity_;
    OrderType type_;
};

// Modify order = Cancel and replace. Requires order, price, qty, side
class OrderModify
{
public:
    OrderModify(OrderId id, Side side, Price newPrice, Quantity newQuantity)
        : id_{id},
          side_{side},
          newPrice_{newPrice},
          newQuantity_{newQuantity}
    {
    }

    OrderId getId() const { return id_; }
    Price getNewPrice() const { return newPrice_; }
    Side getSide() const { return side_; }
    Quantity getNewQuantity() const { return newQuantity_; }

    // Essentially we are making a new order given the modify details
    OrderPtr toOrderPtr(OrderType type) const
    {
        return std::make_shared<Order>(id_, side_, newPrice_, newQuantity_, type);
    }

private:
    OrderId id_;
    Price newPrice_;
    Quantity newQuantity_;
    Side side_;
};

// Match Order. Aggregation of bid and ask
struct TradeInfo
{
    OrderId orderId_;
    Price price_;
    Quantity quantity_;
};

class Trade
{
public:
    Trade(const TradeInfo &bidTrade, const TradeInfo &askTrade)
        : bidTrade_{bidTrade},
          askTrade_{askTrade}

    {
    }

    const TradeInfo &getBidTradeInfo() const { return bidTrade_; }
    const TradeInfo &getAskTradeInfo() const { return askTrade_; }

private:
    TradeInfo bidTrade_;
    TradeInfo askTrade_;
};

using Price = std::int32_t;
using Quantity = std::uint32_t;
using OrderId = std::uint64_t;
using LevelInfos = std::vector<LevelInfo>;
using OrderPtr = std::shared_ptr<Order>;
using OrderPtrs = std::list<OrderPtr>; // Data structure to hokd list of orders at each price level
using Trades = std::vector<Trade>;     // Handle multiple trades at once
using OrderIds = std::vector<OrderId>;