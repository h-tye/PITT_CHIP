#include <iostream>
#include <fstream>
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
#include <random>

enum class OrderType
{
    GoodTillCancel, // Limit Order that remains until canceled or filled
    FillAndKill,    // Immediate or cancel order - fills as much as possible and cancels the rest
    FillOrKill,     // Fill or kill order - must be filled entirely or canceled
    Market,         // Market order - executes immediately at the best available price
    GoodForDay      // Good for day order - remains active until the end of the trading day
};

enum class Side
{
    Buy,
    Sell
};

enum class Action
{
    Add,
    Cancel,
    Modify,
    Execute,
    Null
};

using Price = std::double_t;
using Quantity = std::uint32_t;
using OrderId = std::uint64_t;
using OrderIds = std::vector<OrderId>;
using Timestamp = std::uint64_t;

class Order
{
public:
    // Constructor for market order, we don't care about price
    Order(OrderId id, Side side, Quantity quantity, OrderType type)
        : id_{id},
          side_{side},
          price_{-1},
          action_{Action::Null},
          initialQuantity_{quantity},
          remainingQuantity_{quantity},
          type_{type},
          timestamp_{static_cast<Timestamp>(std::time(nullptr))}
    {
    }

    Order(OrderId id, Side side, Price price, Quantity quantity, OrderType type, Action action)
        : id_{id},
          side_{side},
          price_{price},
          action_{action},
          initialQuantity_{quantity},
          remainingQuantity_{quantity},
          type_{type},
          timestamp_{static_cast<Timestamp>(std::time(nullptr))}
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

    // Comparator for priority queue based on timestamp
    struct TimestampComparator
    {
        bool operator()(const Order &a, const Order &b) const
        {

            return a.timestamp_ > b.timestamp_;
        }
    };

private:
    OrderId id_;
    Side side_;
    Price price_;
    Quantity initialQuantity_;
    Quantity remainingQuantity_;
    OrderType type_;
    Action action_;
    Timestamp timestamp_;
};

class PriceLevel
{
private:
    const Price price_;
    Quantity totalQuantity_;
    std::map<OrderId, Order> levelOrders_; // Although a queue is more appropriate, map is used for easy removal of orders by ID

public:
    PriceLevel(Price price)
        : price_{price}, totalQuantity_{0}
    {
    }

    Price getPrice() const { return price_; }

    Quantity getTotalQuantity() const { return totalQuantity_; }

    void addOrder(const Order &order)
    {
        levelOrders_.emplace(order.getId(), order);
        totalQuantity_ += order.getRemainingQuantity();
    }

    void removeOrder(const Order &order)
    {
        levelOrders_.erase(order.getId());
        totalQuantity_ -= order.getRemainingQuantity();
    }

    std::map<OrderId, Order> &getOrders() { return levelOrders_; }
};
