#pragma once

#include <utility>
#include <string>

namespace nvbench
{

enum class axis_type
{
  type,
  int64,
  float64,
  string
};

struct axis_base
{
  virtual ~axis_base();

  [[nodiscard]] const std::string &get_name() const { return m_name; }

  [[nodiscard]] axis_type get_type() const { return m_type; }

  [[nodiscard]] std::size_t get_size() const { return this->do_get_size(); }

  [[nodiscard]] std::string get_user_string(std::size_t i) const
  {
    return this->do_get_user_string(i);
  }

  [[nodiscard]] std::string get_user_description(std::size_t i) const
  {
    return this->do_get_user_description(i);
  }

protected:
  axis_base(std::string name, axis_type type)
      : m_name{std::move(name)}
      , m_type{type}
  {}

private:
  virtual std::size_t do_get_size() const                        = 0;
  virtual std::string do_get_user_string(std::size_t) const      = 0;
  virtual std::string do_get_user_description(std::size_t) const = 0;

  std::string m_name;
  axis_type m_type;
};

} // namespace nvbench