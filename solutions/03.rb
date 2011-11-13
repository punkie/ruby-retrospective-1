require 'bigdecimal'
require 'bigdecimal/util'

module Constants
  LOWER_PRICE_BOUND = ('0.01').to_d
  HIGHER_PRICE_BOUND = ('999.99').to_d
  PRODUCT_MAX_LENGHT = 40
end

class Promotions
  def self.create(hash)
    name, options = hash.first

    case name
      when :get_one_free then GetOneFree.new options
      when :package      then PackageDiscount.new *options.first
      when :threshold    then ThresholdDiscount.new *options.first
      else NoPromotion.new
    end
  end

  class GetOneFree
    def initialize(nth_item_free)
      @nth_item_free = nth_item_free
    end
  
    def discount(count, price)
      (count / @nth_item_free) * price
    end
  
    def name
      "buy #{@nth_item_free - 1}, get 1 free"
    end
  end
  
  class PackageDiscount
    def initialize(size, percent)
      @size    = size
      @percent = percent
    end
  
    def discount(count, price)
      multiplier       = @percent / '100'.to_d
      package_discount = price * multiplier * @size
      packages         = count / @size
  
      package_discount * packages
    end
  
    def name
      'get %d%% off for every %s' % [@percent, @size]
    end
  end
  
  class ThresholdDiscount
    def initialize(threshold, percent)
      @threshold = threshold
      @percent   = percent
    end
  
    def discount(count, price)
      multiplier            = @percent / '100'.to_d
      item_discount         = price * multiplier
      items_above_threshold = [count - @threshold, 0].max
  
      items_above_threshold * item_discount
    end
  
    def name
      suffix = {1 => 'st', 2 => 'nd', 3 => 'rd'}.fetch @threshold, 'th'
      '%2.f%% off of every after the %d%s' % [@percent, @threshold, suffix]
    end
  end
  
  class NoPromotion
    def discount(count, price)
      0
    end
  
    def name
      ''
    end
  end
end

class Coupon
  def self.build(name,type)
    case type.keys.first
      when :percent then PercentOff.new name, type[:percent]
      when :amount  then AmountOff.new  name, type[:amount]
      else raise "Unknown coupon: #{type.inspect}"
    end
  end

  class PercentOff
    attr_reader :name

    def initialize(name, percent)
      @name    = name
      @percent = percent
    end

    def discount(order_price)
      (@percent / '100'.to_d) * order_price
    end

    def description
      "%d%% off" % @percent
    end
  end

  class AmountOff
    attr_reader :name

    def initialize(name, amount)
      @name   = name
      @amount = amount
    end

    def discount(order_price)
      [order_price, @amount].min
    end

    def description
      "%-5.2f off" % @amount
    end
  end

  class NilCoupon
    attr_reader :name

    def discount(order_price)
      0
    end
  end
end

class Product
  attr_reader :name, :price, :promotion

  def initialize(name, price, promotion)

    @name      = name
    @price     = price
    @promotion = promotion
  end
end

class Inventory
  include Constants
  def initialize
    @products = []
    @coupons  = []
  end

  def new_cart
    ShoppingCart.new self
  end

  def register(name, price, options = {})
    price     = price.to_d
    promotion = Promotions.create options
    validate_product(name)
    validate_price(price)
    @products << Product.new(name, price, promotion)
  end
  
  def register_coupon(name, type)
    @coupons << Coupon.build(name, type)
  end

  def [](name)
    product = @products.detect { |product| product.name == name }
    if product == nil then raise 'Unexisting product'
    end
    product
  end

  def coupon(name)
    @coupons.detect { |coupon| coupon.name == name } or Coupon::NilCoupon.new
  end
  
  def validate_product(product_name)
    if @products.one? { |product| product.name == product_name }
      raise "Product with that name already exists"
    elsif product_name.length > PRODUCT_MAX_LENGHT
      raise "Product name is too long"
    end  
  end
  
  def validate_price(price) 
    if price < LOWER_PRICE_BOUND or price > HIGHER_PRICE_BOUND
      raise "Price isn't in range"
    end
  end
end

class ShoppingCart
  attr_reader :items, :coupon

  def initialize(inventory)
    @inventory  = inventory
    @items      = []
    @coupon     = Coupon::NilCoupon.new
  end

  def add(product_name, count = 1)
    product = @inventory[product_name]
    item    = @items.detect { |item| item.product == product }

    if item
      #The previous version won't throw exception .. 
      item.increase(count)  
    else
      @items << LineItem.new(product, count)
    end
  end

  def use(coupon_name)
    @coupon = @inventory.coupon coupon_name
  end

  def total
    items_price - coupon_discount
  end

  def items_price
    @items.map(&:price).inject(&:+)
  end

  def coupon_discount
    @coupon.discount items_price
  end

  def invoice
    InvoicePrinter.new(self).to_s
  end
end

class LineItem
  attr_reader :product
  attr_accessor :count

  def initialize(product, count)
    @product = product
    @count   = 0
    
    increase count
  end
  
  
  def increase(count)
    raise 'You have to add at least one item' if count <= 0
    if count + @count > 99
      raise 'Maximum 99 items of each product can be bought'
    end 
    @count += count
  end

  def product_name
    @product.name
  end

  def price
    price_without_discount - discount
  end

  def price_without_discount
    product.price * count
  end

  def discount
    product.promotion.discount(count, product.price)
  end

  def discount_name
    product.promotion.name
  end

  def discounted?
    not discount.zero?
  end
end

class InvoicePrinter
  def initialize(cart)
    @cart = cart
  end

  def to_s
    @output = ""
    print_header_or_footer('header')
    print_items
    print_header_or_footer('footer')
    print_line
    @output
  end

  private

  def print_items
    @cart.items.each do |item|
      print_item_info(item)
    end

    if @cart.coupon_discount.nonzero?
      name = "Coupon #{@cart.coupon.name} - #{@cart.coupon.description}"
      print name, '', amount(-@cart.coupon_discount)
    end
  end
  
  def print_item_info(item)
    print item.product_name, item.count, amount(item.price_without_discount)
    if item.discounted?
      print "  (#{item.discount_name})", '', amount(-item.discount)
    end
  end
  
  def print_header_or_footer(type)
    if(type == 'header')
      print_line
      print 'Name', 'qty', 'price'
      print_line
    elsif(type == 'footer')
      print_line
      print 'TOTAL', '', amount(@cart.total)
    end
  end
  
  def print_line
    @output << "+------------------------------------------------+----------+\n"
  end

  def print(*args)
    @output << "| %-40s %5s | %8s |\n" % args
  end

  def amount(decimal)
    "%5.2f" % decimal
  end
end
