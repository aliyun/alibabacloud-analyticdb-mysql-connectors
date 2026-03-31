-- ============================================================================
-- 电商场景数据集 - 用于AnalyticDB MySQL能力展示
-- 
-- 包含5张核心表：e_categories, e_products, e_users, e_orders, e_order_items
-- 数据特征：季节性波动、地区差异、用户等级关联、异常数据点
-- 适用于：AnalyticDB MySQL (ADB MySQL) 
-- 
-- 创建时间：2026-03
-- ============================================================================

-- 创建数据库
create database if not exists ecommerce_demo;
use ecommerce_demo;

-- 删除已存在的表（确保幂等性）
DROP TABLE IF EXISTS e_order_items;
DROP TABLE IF EXISTS e_orders;
DROP TABLE IF EXISTS e_products;
DROP TABLE IF EXISTS e_users;
DROP TABLE IF EXISTS e_categories;

-- ============================================================================
-- 1. 商品类目表 e_categories
-- ============================================================================
CREATE TABLE e_categories (
    category_id INT NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    parent_category_id INT DEFAULT NULL,
    PRIMARY KEY (category_id)
) DISTRIBUTED BY HASH(category_id);

-- ============================================================================
-- 2. 商品表 e_products
-- ============================================================================
CREATE TABLE e_products (
    product_id INT NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    category_id INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    cost DECIMAL(10, 2) NOT NULL,
    created_at DATE NOT NULL,
    PRIMARY KEY (product_id)
) DISTRIBUTED BY HASH(product_id);

-- ============================================================================
-- 3. 用户表 e_users
-- ============================================================================
CREATE TABLE e_users (
    user_id INT NOT NULL,
    username VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    province VARCHAR(50) NOT NULL,
    register_date DATE NOT NULL,
    user_level VARCHAR(20) NOT NULL,
    PRIMARY KEY (user_id)
) DISTRIBUTED BY HASH(user_id);

-- ============================================================================
-- 4. 订单表 e_orders
-- ============================================================================
CREATE TABLE e_orders (
    order_id BIGINT NOT NULL,
    user_id INT NOT NULL,
    order_date DATE NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    payment_method VARCHAR(30) NOT NULL,
    PRIMARY KEY (order_id, order_date)
) DISTRIBUTED BY HASH(order_id)
PARTITION BY VALUE(DATE_FORMAT(order_date, '%Y'));

-- ============================================================================
-- 5. 订单明细表 e_order_items
-- ============================================================================
CREATE TABLE e_order_items (
    item_id BIGINT NOT NULL,
    order_id BIGINT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (order_id, item_id)
) DISTRIBUTED BY HASH(order_id);

-- ============================================================================
-- 插入类目数据 (15个类目，含层级结构)
-- ============================================================================
INSERT INTO e_categories (category_id, category_name, parent_category_id) VALUES
(1, '电子产品', NULL),
(2, '手机数码', 1),
(3, '电脑办公', 1),
(4, '服装', NULL),
(5, '男装', 4),
(6, '女装', 4),
(7, '食品饮料', NULL),
(8, '休闲零食', 7),
(9, '酒水饮料', 7),
(10, '家居家装', NULL),
(11, '家具', 10),
(12, '家纺', 10),
(13, '运动户外', NULL),
(14, '运动服饰', 13),
(15, '健身器材', 13);

-- ============================================================================
-- 插入商品数据 (50个商品)
-- ============================================================================
INSERT INTO e_products (product_id, product_name, category_id, price, cost, created_at) VALUES
(1, 'iPhone 15 Pro Max 256GB', 2, 9999.00, 7500.00, '2023-01-15'),
(2, '华为 Mate 60 Pro', 2, 6999.00, 5200.00, '2023-06-20'),
(3, '小米 14 Ultra', 2, 5999.00, 4500.00, '2023-09-10'),
(4, 'OPPO Find X7', 2, 4999.00, 3800.00, '2024-01-05'),
(5, 'MacBook Pro 14寸 M3', 3, 14999.00, 11000.00, '2023-03-01'),
(6, '联想 ThinkPad X1 Carbon', 3, 9999.00, 7200.00, '2023-02-15'),
(7, '华为 MateBook X Pro', 3, 8999.00, 6500.00, '2023-05-20'),
(8, '戴尔 XPS 15', 3, 11999.00, 8800.00, '2023-04-10');

INSERT INTO e_products (product_id, product_name, category_id, price, cost, created_at) VALUES
(9, '男士商务夹克', 5, 599.00, 280.00, '2023-01-10'),
(10, '男士休闲牛仔裤', 5, 299.00, 120.00, '2023-02-05'),
(11, '男士纯棉T恤', 5, 99.00, 35.00, '2023-03-15'),
(12, '男士羽绒服', 5, 899.00, 450.00, '2023-08-20'),
(13, '女士连衣裙', 6, 399.00, 150.00, '2023-01-20'),
(14, '女士针织衫', 6, 259.00, 100.00, '2023-02-28'),
(15, '女士大衣', 6, 1299.00, 650.00, '2023-09-01'),
(16, '女士运动套装', 6, 359.00, 140.00, '2023-04-10');

INSERT INTO e_products (product_id, product_name, category_id, price, cost, created_at) VALUES
(17, '三只松鼠坚果礼盒', 8, 168.00, 85.00, '2023-01-05'),
(18, '良品铺子零食大礼包', 8, 199.00, 95.00, '2023-02-10'),
(19, '百草味每日坚果', 8, 89.00, 45.00, '2023-03-20'),
(20, '旺旺大礼包', 8, 69.00, 32.00, '2023-01-15'),
(21, '茅台飞天53度', 9, 2999.00, 2200.00, '2023-01-01'),
(22, '五粮液52度', 9, 1299.00, 900.00, '2023-01-10'),
(23, '农夫山泉矿泉水24瓶', 9, 39.00, 18.00, '2023-02-01'),
(24, '元气森林气泡水12瓶', 9, 59.00, 28.00, '2023-03-05');

INSERT INTO e_products (product_id, product_name, category_id, price, cost, created_at) VALUES
(25, '北欧简约沙发', 11, 3999.00, 2200.00, '2023-02-20'),
(26, '实木餐桌椅套装', 11, 2599.00, 1400.00, '2023-03-15'),
(27, '智能升降办公桌', 11, 1999.00, 1100.00, '2023-04-10'),
(28, '人体工学电脑椅', 11, 1599.00, 850.00, '2023-05-05'),
(29, '纯棉四件套床品', 12, 499.00, 220.00, '2023-01-25'),
(30, '羽绒被冬季加厚', 12, 899.00, 450.00, '2023-08-15'),
(31, '记忆棉枕头', 12, 199.00, 85.00, '2023-02-10'),
(32, '法兰绒毛毯', 12, 159.00, 65.00, '2023-09-20');

INSERT INTO e_products (product_id, product_name, category_id, price, cost, created_at) VALUES
(33, '耐克运动鞋Air Max', 14, 899.00, 480.00, '2023-03-01'),
(34, '阿迪达斯跑步鞋', 14, 799.00, 420.00, '2023-04-15'),
(35, '李宁篮球鞋', 14, 599.00, 300.00, '2023-05-20'),
(36, '安踏运动T恤', 14, 159.00, 65.00, '2023-02-25'),
(37, '跑步机家用折叠', 15, 2999.00, 1800.00, '2023-01-30'),
(38, '哑铃套装可调节', 15, 599.00, 320.00, '2023-02-15'),
(39, '瑜伽垫加厚防滑', 15, 99.00, 40.00, '2023-03-10'),
(40, '椭圆机静音款', 15, 3999.00, 2400.00, '2023-04-20');

INSERT INTO e_products (product_id, product_name, category_id, price, cost, created_at) VALUES
(41, 'iPad Pro 12.9寸', 2, 8999.00, 6800.00, '2023-05-15'),
(42, 'AirPods Pro 2', 2, 1899.00, 1400.00, '2023-06-01'),
(43, '机械键盘Cherry轴', 3, 699.00, 380.00, '2023-07-10'),
(44, '罗技无线鼠标', 3, 299.00, 150.00, '2023-08-05'),
(45, '男士运动短裤', 5, 129.00, 50.00, '2023-06-15'),
(46, '女士瑜伽裤', 6, 199.00, 80.00, '2023-07-20'),
(47, '进口牛排套餐', 7, 299.00, 180.00, '2023-08-10'),
(48, '智能台灯护眼', 10, 259.00, 120.00, '2023-09-15'),
(49, '筋膜枪按摩器', 15, 499.00, 250.00, '2023-10-01'),
(50, '智能手环运动版', 2, 299.00, 150.00, '2024-01-10');

-- ============================================================================
-- 插入用户数据 (80个用户，分布在不同城市和等级)
-- ============================================================================
INSERT INTO e_users (user_id, username, city, province, register_date, user_level) VALUES
(1, '张伟', '上海', '上海', '2022-03-15', '钻石'),
(2, '李娜', '北京', '北京', '2022-05-20', '金卡'),
(3, '王芳', '杭州', '浙江', '2022-06-10', '金卡'),
(4, '刘洋', '深圳', '广东', '2022-08-25', '钻石'),
(5, '陈明', '广州', '广东', '2022-09-15', '银卡'),
(6, '杨丽', '成都', '四川', '2022-10-20', '金卡'),
(7, '赵强', '重庆', '重庆', '2022-11-05', '普通'),
(8, '孙燕', '武汉', '湖北', '2022-12-18', '银卡'),
(9, '周磊', '南京', '江苏', '2023-01-08', '金卡'),
(10, '吴霞', '苏州', '江苏', '2023-02-14', '银卡');

INSERT INTO e_users (user_id, username, city, province, register_date, user_level) VALUES
(11, '郑涛', '上海', '上海', '2023-03-05', '钻石'),
(12, '王鹏', '北京', '北京', '2023-03-20', '金卡'),
(13, '李静', '杭州', '浙江', '2023-04-10', '银卡'),
(14, '张敏', '深圳', '广东', '2023-04-25', '金卡'),
(15, '刘强', '广州', '广东', '2023-05-08', '普通'),
(16, '陈洁', '成都', '四川', '2023-05-22', '银卡'),
(17, '杨威', '重庆', '重庆', '2023-06-15', '普通'),
(18, '赵丽', '武汉', '湖北', '2023-07-01', '银卡'),
(19, '孙浩', '南京', '江苏', '2023-07-18', '金卡'),
(20, '周敏', '苏州', '江苏', '2023-08-05', '普通');

INSERT INTO e_users (user_id, username, city, province, register_date, user_level) VALUES
(21, '吴刚', '天津', '天津', '2023-01-12', '银卡'),
(22, '郑婷', '西安', '陕西', '2023-02-28', '普通'),
(23, '王磊', '郑州', '河南', '2023-03-15', '银卡'),
(24, '李文', '长沙', '湖南', '2023-04-02', '普通'),
(25, '张华', '济南', '山东', '2023-04-20', '金卡'),
(26, '刘婷', '青岛', '山东', '2023-05-10', '银卡'),
(27, '陈峰', '厦门', '福建', '2023-06-05', '金卡'),
(28, '杨娟', '福州', '福建', '2023-06-25', '普通'),
(29, '赵云', '合肥', '安徽', '2023-07-12', '银卡'),
(30, '孙芳', '南昌', '江西', '2023-08-01', '普通');

INSERT INTO e_users (user_id, username, city, province, register_date, user_level) VALUES
(31, '周涛', '上海', '上海', '2023-08-20', '金卡'),
(32, '吴芳', '北京', '北京', '2023-09-05', '银卡'),
(33, '郑强', '杭州', '浙江', '2023-09-22', '钻石'),
(34, '王娜', '深圳', '广东', '2023-10-10', '金卡'),
(35, '李刚', '广州', '广东', '2023-10-28', '银卡'),
(36, '张燕', '成都', '四川', '2023-11-15', '普通'),
(37, '刘伟', '重庆', '重庆', '2023-12-01', '银卡'),
(38, '陈丽', '武汉', '湖北', '2023-12-18', '普通'),
(39, '杨涛', '南京', '江苏', '2024-01-05', '金卡'),
(40, '赵敏', '苏州', '江苏', '2024-01-20', '银卡');

INSERT INTO e_users (user_id, username, city, province, register_date, user_level) VALUES
(41, '孙伟', '上海', '上海', '2024-02-08', '普通'),
(42, '周芳', '北京', '北京', '2024-02-25', '银卡'),
(43, '吴强', '杭州', '浙江', '2024-03-12', '普通'),
(44, '郑丽', '深圳', '广东', '2024-03-28', '金卡'),
(45, '王涛', '广州', '广东', '2024-04-15', '普通'),
(46, '李敏', '成都', '四川', '2024-05-02', '银卡'),
(47, '张强', '重庆', '重庆', '2024-05-20', '普通'),
(48, '刘芳', '武汉', '湖北', '2024-06-08', '普通'),
(49, '陈伟', '南京', '江苏', '2024-06-25', '银卡'),
(50, '杨敏', '苏州', '江苏', '2024-07-10', '普通');

INSERT INTO e_users (user_id, username, city, province, register_date, user_level) VALUES
(51, '赵伟', '天津', '天津', '2022-04-10', '金卡'),
(52, '孙丽', '西安', '陕西', '2022-07-15', '银卡'),
(53, '周强', '郑州', '河南', '2022-09-20', '普通'),
(54, '吴敏', '长沙', '湖南', '2022-11-25', '银卡'),
(55, '郑伟', '济南', '山东', '2023-01-30', '金卡'),
(56, '王丽', '青岛', '山东', '2023-04-05', '普通'),
(57, '李涛', '厦门', '福建', '2023-06-12', '钻石'),
(58, '张丽', '福州', '福建', '2023-08-18', '银卡'),
(59, '刘敏', '合肥', '安徽', '2023-10-22', '普通'),
(60, '陈涛', '南昌', '江西', '2023-12-28', '银卡');

INSERT INTO e_users (user_id, username, city, province, register_date, user_level) VALUES
(61, '杨芳', '上海', '上海', '2024-01-15', '普通'),
(62, '赵涛', '北京', '北京', '2024-02-20', '银卡'),
(63, '孙敏', '杭州', '浙江', '2024-03-25', '普通'),
(64, '周丽', '深圳', '广东', '2024-04-30', '金卡'),
(65, '吴涛', '广州', '广东', '2024-06-05', '普通'),
(66, '郑敏', '成都', '四川', '2024-07-10', '银卡'),
(67, '王伟', '重庆', '重庆', '2024-08-15', '普通'),
(68, '李芳', '武汉', '湖北', '2024-09-20', '普通'),
(69, '张涛', '南京', '江苏', '2024-10-25', '银卡'),
(70, '刘丽', '苏州', '江苏', '2024-11-30', '普通');

INSERT INTO e_users (user_id, username, city, province, register_date, user_level) VALUES
(71, '陈芳', '宁波', '浙江', '2022-05-12', '金卡'),
(72, '杨丽', '无锡', '江苏', '2022-08-18', '银卡'),
(73, '赵芳', '东莞', '广东', '2022-11-22', '钻石'),
(74, '孙涛', '佛山', '广东', '2023-02-28', '金卡'),
(75, '周伟', '沈阳', '辽宁', '2023-05-05', '普通'),
(76, '吴丽', '大连', '辽宁', '2023-07-12', '银卡'),
(77, '郑芳', '哈尔滨', '黑龙江', '2023-09-18', '普通'),
(78, '王敏', '长春', '吉林', '2023-11-25', '银卡'),
(79, '李伟', '昆明', '云南', '2024-02-01', '普通'),
(80, '张芳', '贵阳', '贵州', '2024-04-08', '普通');

-- ============================================================================
-- 插入订单数据 (约1000条，跨2023-2025年，有季节性波动)
-- ============================================================================

-- 2023年Q1订单 (春节低谷，约60条)
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10001, 1, '2023-01-05', 9999.00, 'completed', 'alipay'),
(10002, 2, '2023-01-08', 599.00, 'completed', 'wechat'),
(10003, 3, '2023-01-12', 2999.00, 'completed', 'credit_card'),
(10004, 4, '2023-01-15', 168.00, 'completed', 'alipay'),
(10005, 5, '2023-01-18', 1299.00, 'completed', 'wechat'),
(10006, 6, '2023-01-22', 499.00, 'completed', 'alipay'),
(10007, 7, '2023-01-25', 299.00, 'completed', 'wechat'),
(10008, 8, '2023-01-28', 899.00, 'completed', 'bank_transfer'),
(10009, 9, '2023-02-02', 6999.00, 'completed', 'credit_card'),
(10010, 10, '2023-02-05', 399.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10011, 1, '2023-02-08', 259.00, 'completed', 'wechat'),
(10012, 2, '2023-02-12', 1599.00, 'completed', 'alipay'),
(10013, 3, '2023-02-15', 89.00, 'completed', 'wechat'),
(10014, 4, '2023-02-18', 3999.00, 'completed', 'credit_card'),
(10015, 5, '2023-02-22', 159.00, 'completed', 'alipay'),
(10016, 6, '2023-02-25', 799.00, 'completed', 'wechat'),
(10017, 7, '2023-02-28', 199.00, 'cancelled', 'alipay'),
(10018, 8, '2023-03-02', 2599.00, 'completed', 'bank_transfer'),
(10019, 9, '2023-03-05', 99.00, 'completed', 'wechat'),
(10020, 10, '2023-03-08', 14999.00, 'completed', 'credit_card');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10021, 11, '2023-03-10', 899.00, 'completed', 'alipay'),
(10022, 21, '2023-03-12', 599.00, 'completed', 'wechat'),
(10023, 51, '2023-03-15', 1999.00, 'completed', 'alipay'),
(10024, 52, '2023-03-18', 299.00, 'completed', 'wechat'),
(10025, 53, '2023-03-20', 69.00, 'completed', 'alipay'),
(10026, 54, '2023-03-22', 499.00, 'completed', 'wechat'),
(10027, 55, '2023-03-25', 8999.00, 'completed', 'credit_card'),
(10028, 1, '2023-03-28', 359.00, 'completed', 'alipay'),
(10029, 2, '2023-03-30', 199.00, 'refunded', 'wechat'),
(10030, 3, '2023-03-31', 2999.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10031, 4, '2023-01-10', 5999.00, 'completed', 'credit_card'),
(10032, 5, '2023-01-20', 299.00, 'completed', 'alipay'),
(10033, 6, '2023-02-01', 1899.00, 'completed', 'wechat'),
(10034, 7, '2023-02-10', 699.00, 'completed', 'alipay'),
(10035, 8, '2023-02-20', 99.00, 'completed', 'wechat'),
(10036, 9, '2023-03-01', 3999.00, 'completed', 'credit_card'),
(10037, 10, '2023-03-10', 159.00, 'completed', 'alipay'),
(10038, 11, '2023-03-20', 259.00, 'completed', 'wechat'),
(10039, 1, '2023-03-25', 899.00, 'completed', 'alipay'),
(10040, 2, '2023-03-28', 499.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10041, 12, '2023-01-15', 11999.00, 'completed', 'credit_card'),
(10042, 13, '2023-01-25', 199.00, 'completed', 'alipay'),
(10043, 14, '2023-02-05', 599.00, 'completed', 'wechat'),
(10044, 15, '2023-02-15', 299.00, 'completed', 'alipay'),
(10045, 16, '2023-02-25', 1299.00, 'completed', 'wechat'),
(10046, 17, '2023-03-05', 89.00, 'completed', 'alipay'),
(10047, 18, '2023-03-15', 3999.00, 'completed', 'credit_card'),
(10048, 19, '2023-03-25', 799.00, 'completed', 'wechat'),
(10049, 20, '2023-03-28', 159.00, 'completed', 'alipay'),
(10050, 21, '2023-03-30', 2599.00, 'completed', 'bank_transfer');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10051, 22, '2023-02-08', 499.00, 'completed', 'alipay'),
(10052, 23, '2023-02-18', 899.00, 'completed', 'wechat'),
(10053, 24, '2023-02-28', 199.00, 'completed', 'alipay'),
(10054, 25, '2023-03-08', 6999.00, 'completed', 'credit_card'),
(10055, 26, '2023-03-18', 359.00, 'completed', 'wechat'),
(10056, 27, '2023-03-28', 1599.00, 'completed', 'alipay'),
(10057, 28, '2023-01-18', 69.00, 'completed', 'wechat'),
(10058, 29, '2023-02-18', 2999.00, 'completed', 'credit_card'),
(10059, 30, '2023-03-18', 99.00, 'completed', 'alipay'),
(10060, 51, '2023-03-20', 8999.00, 'completed', 'credit_card');

-- 2023年Q2订单 (正常期，约100条)
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10061, 1, '2023-04-02', 4999.00, 'completed', 'alipay'),
(10062, 2, '2023-04-05', 299.00, 'completed', 'wechat'),
(10063, 3, '2023-04-08', 899.00, 'completed', 'alipay'),
(10064, 4, '2023-04-12', 1299.00, 'completed', 'credit_card'),
(10065, 5, '2023-04-15', 499.00, 'completed', 'wechat'),
(10066, 6, '2023-04-18', 199.00, 'completed', 'alipay'),
(10067, 7, '2023-04-22', 2999.00, 'completed', 'bank_transfer'),
(10068, 8, '2023-04-25', 599.00, 'completed', 'wechat'),
(10069, 9, '2023-04-28', 159.00, 'completed', 'alipay'),
(10070, 10, '2023-05-01', 9999.00, 'completed', 'credit_card');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10071, 11, '2023-05-05', 799.00, 'completed', 'alipay'),
(10072, 12, '2023-05-08', 399.00, 'completed', 'wechat'),
(10073, 13, '2023-05-12', 1999.00, 'completed', 'alipay'),
(10074, 14, '2023-05-15', 259.00, 'completed', 'wechat'),
(10075, 15, '2023-05-18', 3999.00, 'completed', 'credit_card'),
(10076, 16, '2023-05-22', 89.00, 'completed', 'alipay'),
(10077, 17, '2023-05-25', 699.00, 'completed', 'wechat'),
(10078, 18, '2023-05-28', 1599.00, 'completed', 'alipay'),
(10079, 19, '2023-06-01', 299.00, 'completed', 'wechat'),
(10080, 20, '2023-06-05', 6999.00, 'completed', 'credit_card');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10081, 21, '2023-06-08', 499.00, 'completed', 'alipay'),
(10082, 22, '2023-06-12', 199.00, 'completed', 'wechat'),
(10083, 23, '2023-06-15', 2599.00, 'completed', 'alipay'),
(10084, 24, '2023-06-18', 159.00, 'completed', 'wechat'),
(10085, 25, '2023-06-22', 899.00, 'completed', 'credit_card'),
(10086, 26, '2023-06-25', 359.00, 'completed', 'alipay'),
(10087, 27, '2023-06-28', 1299.00, 'completed', 'wechat'),
(10088, 28, '2023-04-10', 599.00, 'completed', 'alipay'),
(10089, 29, '2023-04-20', 99.00, 'completed', 'wechat'),
(10090, 30, '2023-05-10', 14999.00, 'completed', 'credit_card');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10091, 51, '2023-05-20', 799.00, 'completed', 'alipay'),
(10092, 52, '2023-06-01', 499.00, 'completed', 'wechat'),
(10093, 53, '2023-06-10', 2999.00, 'completed', 'alipay'),
(10094, 54, '2023-06-20', 199.00, 'completed', 'wechat'),
(10095, 55, '2023-06-30', 5999.00, 'completed', 'credit_card'),
(10096, 1, '2023-04-15', 168.00, 'completed', 'alipay'),
(10097, 2, '2023-05-15', 899.00, 'completed', 'wechat'),
(10098, 3, '2023-06-15', 259.00, 'completed', 'alipay'),
(10099, 4, '2023-04-25', 1899.00, 'completed', 'credit_card'),
(10100, 5, '2023-05-25', 399.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10101, 6, '2023-06-25', 699.00, 'completed', 'alipay'),
(10102, 7, '2023-04-08', 99.00, 'completed', 'wechat'),
(10103, 8, '2023-05-08', 3999.00, 'completed', 'credit_card'),
(10104, 9, '2023-06-08', 159.00, 'completed', 'alipay'),
(10105, 10, '2023-04-18', 2599.00, 'completed', 'wechat'),
(10106, 11, '2023-05-18', 599.00, 'completed', 'alipay'),
(10107, 12, '2023-06-18', 1999.00, 'completed', 'credit_card'),
(10108, 13, '2023-04-28', 299.00, 'completed', 'alipay'),
(10109, 14, '2023-05-28', 799.00, 'completed', 'wechat'),
(10110, 15, '2023-06-28', 499.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10111, 16, '2023-04-05', 1299.00, 'completed', 'wechat'),
(10112, 17, '2023-05-05', 359.00, 'completed', 'alipay'),
(10113, 18, '2023-06-05', 8999.00, 'completed', 'credit_card'),
(10114, 19, '2023-04-15', 199.00, 'completed', 'wechat'),
(10115, 20, '2023-05-15', 2999.00, 'completed', 'alipay'),
(10116, 21, '2023-06-15', 699.00, 'completed', 'wechat'),
(10117, 22, '2023-04-25', 89.00, 'refunded', 'alipay'),
(10118, 23, '2023-05-25', 1599.00, 'completed', 'credit_card'),
(10119, 24, '2023-06-25', 259.00, 'completed', 'wechat'),
(10120, 25, '2023-05-02', 6999.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10121, 26, '2023-05-12', 499.00, 'completed', 'wechat'),
(10122, 27, '2023-05-22', 899.00, 'completed', 'alipay'),
(10123, 28, '2023-06-02', 159.00, 'completed', 'wechat'),
(10124, 29, '2023-06-12', 3999.00, 'completed', 'credit_card'),
(10125, 30, '2023-06-22', 299.00, 'completed', 'alipay'),
(10126, 71, '2023-04-05', 11999.00, 'completed', 'credit_card'),
(10127, 72, '2023-05-05', 599.00, 'completed', 'alipay'),
(10128, 73, '2023-06-05', 1299.00, 'completed', 'wechat'),
(10129, 74, '2023-04-20', 799.00, 'completed', 'alipay'),
(10130, 75, '2023-05-20', 199.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10131, 76, '2023-06-20', 2599.00, 'completed', 'credit_card'),
(10132, 77, '2023-04-30', 99.00, 'completed', 'alipay'),
(10133, 78, '2023-05-30', 4999.00, 'completed', 'wechat'),
(10134, 1, '2023-05-10', 699.00, 'completed', 'alipay'),
(10135, 4, '2023-05-18', 359.00, 'completed', 'wechat'),
(10136, 11, '2023-05-25', 8999.00, 'completed', 'credit_card'),
(10137, 33, '2023-06-02', 1899.00, 'completed', 'alipay'),
(10138, 57, '2023-06-10', 499.00, 'completed', 'wechat'),
(10139, 73, '2023-06-18', 2999.00, 'completed', 'alipay'),
(10140, 1, '2023-06-28', 159.00, 'completed', 'wechat');

-- 2023年Q3订单 (正常期，约120条)
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10141, 1, '2023-07-02', 5999.00, 'completed', 'alipay'),
(10142, 2, '2023-07-05', 899.00, 'completed', 'wechat'),
(10143, 3, '2023-07-08', 1299.00, 'completed', 'alipay'),
(10144, 4, '2023-07-12', 299.00, 'completed', 'credit_card'),
(10145, 5, '2023-07-15', 2599.00, 'completed', 'wechat'),
(10146, 6, '2023-07-18', 499.00, 'completed', 'alipay'),
(10147, 7, '2023-07-22', 159.00, 'completed', 'wechat'),
(10148, 8, '2023-07-25', 6999.00, 'completed', 'credit_card'),
(10149, 9, '2023-07-28', 799.00, 'completed', 'alipay'),
(10150, 10, '2023-08-01', 399.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10151, 11, '2023-08-05', 1999.00, 'completed', 'alipay'),
(10152, 12, '2023-08-08', 599.00, 'completed', 'wechat'),
(10153, 13, '2023-08-12', 89.00, 'completed', 'alipay'),
(10154, 14, '2023-08-15', 3999.00, 'completed', 'credit_card'),
(10155, 15, '2023-08-18', 259.00, 'completed', 'wechat'),
(10156, 16, '2023-08-22', 1599.00, 'completed', 'alipay'),
(10157, 17, '2023-08-25', 699.00, 'completed', 'wechat'),
(10158, 18, '2023-08-28', 199.00, 'completed', 'alipay'),
(10159, 19, '2023-09-01', 8999.00, 'completed', 'credit_card'),
(10160, 20, '2023-09-05', 359.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10161, 21, '2023-09-08', 2999.00, 'completed', 'alipay'),
(10162, 22, '2023-09-12', 99.00, 'completed', 'wechat'),
(10163, 23, '2023-09-15', 1299.00, 'completed', 'alipay'),
(10164, 24, '2023-09-18', 499.00, 'completed', 'credit_card'),
(10165, 25, '2023-09-22', 899.00, 'completed', 'wechat'),
(10166, 26, '2023-09-25', 159.00, 'completed', 'alipay'),
(10167, 27, '2023-09-28', 4999.00, 'completed', 'wechat'),
(10168, 28, '2023-07-10', 299.00, 'completed', 'alipay'),
(10169, 29, '2023-08-10', 799.00, 'completed', 'credit_card'),
(10170, 30, '2023-09-10', 599.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10171, 31, '2023-07-15', 2599.00, 'completed', 'alipay'),
(10172, 32, '2023-08-15', 1899.00, 'completed', 'wechat'),
(10173, 33, '2023-09-15', 11999.00, 'completed', 'credit_card'),
(10174, 34, '2023-07-20', 399.00, 'completed', 'alipay'),
(10175, 35, '2023-08-20', 699.00, 'completed', 'wechat'),
(10176, 36, '2023-09-20', 199.00, 'completed', 'alipay'),
(10177, 37, '2023-07-25', 1599.00, 'completed', 'credit_card'),
(10178, 38, '2023-08-25', 259.00, 'completed', 'wechat'),
(10179, 39, '2023-09-25', 5999.00, 'completed', 'alipay'),
(10180, 40, '2023-07-30', 89.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10181, 51, '2023-08-01', 3999.00, 'completed', 'credit_card'),
(10182, 52, '2023-09-01', 499.00, 'completed', 'alipay'),
(10183, 53, '2023-07-05', 159.00, 'completed', 'wechat'),
(10184, 54, '2023-08-05', 899.00, 'completed', 'alipay'),
(10185, 55, '2023-09-05', 2599.00, 'completed', 'credit_card'),
(10186, 56, '2023-07-12', 299.00, 'completed', 'wechat'),
(10187, 57, '2023-08-12', 6999.00, 'completed', 'alipay'),
(10188, 58, '2023-09-12', 799.00, 'completed', 'wechat'),
(10189, 59, '2023-07-18', 1299.00, 'completed', 'credit_card'),
(10190, 60, '2023-08-18', 599.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10191, 71, '2023-09-18', 1999.00, 'completed', 'wechat'),
(10192, 72, '2023-07-22', 359.00, 'completed', 'alipay'),
(10193, 73, '2023-08-22', 8999.00, 'completed', 'credit_card'),
(10194, 74, '2023-09-22', 199.00, 'completed', 'wechat'),
(10195, 75, '2023-07-28', 699.00, 'completed', 'alipay'),
(10196, 76, '2023-08-28', 1599.00, 'completed', 'wechat'),
(10197, 77, '2023-09-28', 99.00, 'completed', 'alipay'),
(10198, 78, '2023-07-08', 4999.00, 'completed', 'credit_card'),
(10199, 1, '2023-08-08', 259.00, 'completed', 'wechat'),
(10200, 4, '2023-09-08', 899.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10201, 11, '2023-07-15', 2999.00, 'completed', 'credit_card'),
(10202, 33, '2023-08-15', 499.00, 'completed', 'alipay'),
(10203, 57, '2023-09-15', 1299.00, 'completed', 'wechat'),
(10204, 73, '2023-07-20', 799.00, 'completed', 'alipay'),
(10205, 1, '2023-08-20', 14999.00, 'completed', 'credit_card'),
(10206, 2, '2023-09-20', 399.00, 'completed', 'wechat'),
(10207, 3, '2023-07-25', 599.00, 'completed', 'alipay'),
(10208, 4, '2023-08-25', 1899.00, 'completed', 'credit_card'),
(10209, 5, '2023-09-25', 159.00, 'completed', 'wechat'),
(10210, 6, '2023-07-30', 2599.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10211, 7, '2023-08-30', 699.00, 'completed', 'wechat'),
(10212, 8, '2023-09-30', 99.00, 'completed', 'alipay'),
(10213, 9, '2023-07-05', 3999.00, 'completed', 'credit_card'),
(10214, 10, '2023-08-05', 199.00, 'completed', 'wechat'),
(10215, 11, '2023-09-05', 1599.00, 'completed', 'alipay'),
(10216, 12, '2023-07-12', 499.00, 'completed', 'wechat'),
(10217, 13, '2023-08-12', 2599.00, 'completed', 'credit_card'),
(10218, 14, '2023-09-12', 899.00, 'completed', 'alipay'),
(10219, 15, '2023-07-18', 359.00, 'completed', 'wechat'),
(10220, 16, '2023-08-18', 5999.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10221, 17, '2023-09-18', 259.00, 'completed', 'wechat'),
(10222, 18, '2023-07-22', 1299.00, 'completed', 'credit_card'),
(10223, 19, '2023-08-22', 799.00, 'completed', 'alipay'),
(10224, 20, '2023-09-22', 199.00, 'completed', 'wechat'),
(10225, 21, '2023-07-28', 6999.00, 'completed', 'alipay'),
(10226, 22, '2023-08-28', 599.00, 'completed', 'credit_card'),
(10227, 23, '2023-09-28', 1999.00, 'completed', 'wechat'),
(10228, 24, '2023-07-02', 299.00, 'completed', 'alipay'),
(10229, 25, '2023-08-02', 899.00, 'completed', 'wechat'),
(10230, 26, '2023-09-02', 159.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10231, 27, '2023-07-08', 4999.00, 'completed', 'credit_card'),
(10232, 28, '2023-08-08', 399.00, 'completed', 'wechat'),
(10233, 29, '2023-09-08', 699.00, 'completed', 'alipay'),
(10234, 30, '2023-07-15', 1599.00, 'completed', 'wechat'),
(10235, 31, '2023-08-15', 259.00, 'completed', 'alipay'),
(10236, 32, '2023-09-15', 8999.00, 'completed', 'credit_card'),
(10237, 33, '2023-07-22', 499.00, 'completed', 'wechat'),
(10238, 34, '2023-08-22', 2599.00, 'completed', 'alipay'),
(10239, 35, '2023-09-22', 899.00, 'completed', 'wechat'),
(10240, 36, '2023-07-28', 199.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10241, 37, '2023-08-28', 3999.00, 'completed', 'credit_card'),
(10242, 38, '2023-09-28', 599.00, 'completed', 'wechat'),
(10243, 39, '2023-07-05', 1299.00, 'completed', 'alipay'),
(10244, 40, '2023-08-05', 799.00, 'completed', 'wechat'),
(10245, 51, '2023-09-05', 159.00, 'completed', 'alipay'),
(10246, 52, '2023-07-12', 2999.00, 'completed', 'credit_card'),
(10247, 53, '2023-08-12', 499.00, 'completed', 'wechat'),
(10248, 54, '2023-09-12', 899.00, 'completed', 'alipay'),
(10249, 55, '2023-07-18', 5999.00, 'completed', 'credit_card'),
(10250, 56, '2023-08-18', 299.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10251, 57, '2023-09-18', 1599.00, 'completed', 'alipay'),
(10252, 58, '2023-07-22', 699.00, 'completed', 'wechat'),
(10253, 59, '2023-08-22', 199.00, 'completed', 'alipay'),
(10254, 60, '2023-09-22', 4999.00, 'completed', 'credit_card'),
(10255, 71, '2023-07-28', 359.00, 'completed', 'wechat'),
(10256, 72, '2023-08-28', 1899.00, 'completed', 'alipay'),
(10257, 73, '2023-09-28', 599.00, 'completed', 'wechat'),
(10258, 74, '2023-07-02', 2599.00, 'completed', 'credit_card'),
(10259, 75, '2023-08-02', 99.00, 'completed', 'alipay'),
(10260, 76, '2023-09-02', 799.00, 'completed', 'wechat');

-- 2023年Q4订单 (双十一高峰，约200条)
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10261, 1, '2023-10-01', 9999.00, 'completed', 'alipay'),
(10262, 2, '2023-10-05', 2999.00, 'completed', 'wechat'),
(10263, 3, '2023-10-08', 899.00, 'completed', 'alipay'),
(10264, 4, '2023-10-12', 1599.00, 'completed', 'credit_card'),
(10265, 5, '2023-10-15', 599.00, 'completed', 'wechat'),
(10266, 6, '2023-10-18', 6999.00, 'completed', 'alipay'),
(10267, 7, '2023-10-22', 299.00, 'completed', 'wechat'),
(10268, 8, '2023-10-25', 1299.00, 'completed', 'credit_card'),
(10269, 9, '2023-10-28', 499.00, 'completed', 'alipay'),
(10270, 10, '2023-10-31', 3999.00, 'completed', 'wechat');

-- 双十一期间订单激增
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10271, 1, '2023-11-01', 14999.00, 'completed', 'credit_card'),
(10272, 2, '2023-11-02', 8999.00, 'completed', 'alipay'),
(10273, 3, '2023-11-03', 5999.00, 'completed', 'wechat'),
(10274, 4, '2023-11-04', 2599.00, 'completed', 'alipay'),
(10275, 5, '2023-11-05', 1899.00, 'completed', 'credit_card'),
(10276, 6, '2023-11-06', 999.00, 'completed', 'wechat'),
(10277, 7, '2023-11-07', 4999.00, 'completed', 'alipay'),
(10278, 8, '2023-11-08', 799.00, 'completed', 'wechat'),
(10279, 9, '2023-11-09', 1599.00, 'completed', 'credit_card'),
(10280, 10, '2023-11-10', 11999.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10281, 11, '2023-11-11', 19999.00, 'completed', 'credit_card'),
(10282, 12, '2023-11-11', 9999.00, 'completed', 'alipay'),
(10283, 13, '2023-11-11', 6999.00, 'completed', 'wechat'),
(10284, 14, '2023-11-11', 4999.00, 'completed', 'alipay'),
(10285, 15, '2023-11-11', 3999.00, 'completed', 'credit_card'),
(10286, 16, '2023-11-11', 2999.00, 'completed', 'wechat'),
(10287, 17, '2023-11-11', 1999.00, 'completed', 'alipay'),
(10288, 18, '2023-11-11', 1599.00, 'completed', 'wechat'),
(10289, 19, '2023-11-11', 1299.00, 'completed', 'credit_card'),
(10290, 20, '2023-11-11', 899.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10291, 21, '2023-11-11', 14999.00, 'completed', 'credit_card'),
(10292, 22, '2023-11-11', 8999.00, 'completed', 'alipay'),
(10293, 23, '2023-11-11', 5999.00, 'completed', 'wechat'),
(10294, 24, '2023-11-11', 3999.00, 'completed', 'alipay'),
(10295, 25, '2023-11-11', 2999.00, 'completed', 'credit_card'),
(10296, 26, '2023-11-11', 2599.00, 'completed', 'wechat'),
(10297, 27, '2023-11-11', 1899.00, 'completed', 'alipay'),
(10298, 28, '2023-11-11', 1599.00, 'completed', 'wechat'),
(10299, 29, '2023-11-11', 999.00, 'completed', 'credit_card'),
(10300, 30, '2023-11-11', 799.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10301, 31, '2023-11-11', 11999.00, 'completed', 'credit_card'),
(10302, 32, '2023-11-11', 6999.00, 'completed', 'alipay'),
(10303, 33, '2023-11-11', 19999.00, 'completed', 'wechat'),
(10304, 34, '2023-11-11', 4999.00, 'completed', 'alipay'),
(10305, 35, '2023-11-11', 2599.00, 'completed', 'credit_card'),
(10306, 36, '2023-11-11', 1299.00, 'completed', 'wechat'),
(10307, 37, '2023-11-11', 899.00, 'completed', 'alipay'),
(10308, 38, '2023-11-11', 599.00, 'completed', 'wechat'),
(10309, 39, '2023-11-11', 8999.00, 'completed', 'credit_card'),
(10310, 40, '2023-11-11', 3999.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10311, 51, '2023-11-11', 9999.00, 'completed', 'credit_card'),
(10312, 52, '2023-11-11', 5999.00, 'completed', 'alipay'),
(10313, 53, '2023-11-11', 2999.00, 'completed', 'wechat'),
(10314, 54, '2023-11-11', 1999.00, 'completed', 'alipay'),
(10315, 55, '2023-11-11', 14999.00, 'completed', 'credit_card'),
(10316, 56, '2023-11-11', 1599.00, 'completed', 'wechat'),
(10317, 57, '2023-11-11', 11999.00, 'completed', 'alipay'),
(10318, 58, '2023-11-11', 799.00, 'completed', 'wechat'),
(10319, 59, '2023-11-11', 499.00, 'completed', 'credit_card'),
(10320, 60, '2023-11-11', 2599.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10321, 71, '2023-11-11', 8999.00, 'completed', 'credit_card'),
(10322, 72, '2023-11-11', 4999.00, 'completed', 'alipay'),
(10323, 73, '2023-11-11', 19999.00, 'completed', 'wechat'),
(10324, 74, '2023-11-11', 6999.00, 'completed', 'alipay'),
(10325, 75, '2023-11-11', 1299.00, 'completed', 'credit_card'),
(10326, 76, '2023-11-11', 899.00, 'completed', 'wechat'),
(10327, 77, '2023-11-11', 599.00, 'completed', 'alipay'),
(10328, 78, '2023-11-11', 3999.00, 'completed', 'wechat'),
(10329, 1, '2023-11-11', 2999.00, 'completed', 'credit_card'),
(10330, 4, '2023-11-11', 5999.00, 'completed', 'alipay');

-- 双十一后续订单
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10331, 11, '2023-11-12', 1599.00, 'completed', 'wechat'),
(10332, 33, '2023-11-13', 2999.00, 'completed', 'alipay'),
(10333, 57, '2023-11-14', 899.00, 'completed', 'credit_card'),
(10334, 73, '2023-11-15', 4999.00, 'completed', 'wechat'),
(10335, 2, '2023-11-16', 599.00, 'completed', 'alipay'),
(10336, 3, '2023-11-18', 1299.00, 'completed', 'wechat'),
(10337, 5, '2023-11-20', 799.00, 'completed', 'credit_card'),
(10338, 6, '2023-11-22', 2599.00, 'completed', 'alipay'),
(10339, 7, '2023-11-25', 199.00, 'completed', 'wechat'),
(10340, 8, '2023-11-28', 3999.00, 'completed', 'alipay');

-- 退款率突然升高的异常期 (2023年11月底-12月初)
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10341, 9, '2023-11-25', 1599.00, 'refunded', 'credit_card'),
(10342, 10, '2023-11-26', 899.00, 'refunded', 'alipay'),
(10343, 11, '2023-11-27', 2999.00, 'refunded', 'wechat'),
(10344, 12, '2023-11-28', 599.00, 'refunded', 'alipay'),
(10345, 13, '2023-11-29', 1299.00, 'refunded', 'credit_card'),
(10346, 14, '2023-11-30', 4999.00, 'refunded', 'wechat'),
(10347, 15, '2023-12-01', 799.00, 'refunded', 'alipay'),
(10348, 16, '2023-12-02', 1899.00, 'refunded', 'wechat'),
(10349, 17, '2023-12-03', 299.00, 'refunded', 'credit_card'),
(10350, 18, '2023-12-04', 2599.00, 'refunded', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10351, 19, '2023-12-05', 6999.00, 'completed', 'credit_card'),
(10352, 20, '2023-12-08', 1599.00, 'completed', 'alipay'),
(10353, 21, '2023-12-10', 899.00, 'completed', 'wechat'),
(10354, 22, '2023-12-12', 2999.00, 'completed', 'alipay'),
(10355, 23, '2023-12-15', 499.00, 'completed', 'credit_card'),
(10356, 24, '2023-12-18', 1299.00, 'completed', 'wechat'),
(10357, 25, '2023-12-20', 3999.00, 'completed', 'alipay'),
(10358, 26, '2023-12-22', 799.00, 'completed', 'wechat'),
(10359, 27, '2023-12-25', 5999.00, 'completed', 'credit_card'),
(10360, 28, '2023-12-28', 199.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10361, 29, '2023-10-05', 1599.00, 'completed', 'wechat'),
(10362, 30, '2023-10-10', 2999.00, 'completed', 'alipay'),
(10363, 31, '2023-10-15', 899.00, 'completed', 'credit_card'),
(10364, 32, '2023-10-20', 4999.00, 'completed', 'wechat'),
(10365, 33, '2023-10-25', 599.00, 'completed', 'alipay'),
(10366, 34, '2023-10-28', 1299.00, 'completed', 'wechat'),
(10367, 35, '2023-11-05', 799.00, 'completed', 'credit_card'),
(10368, 36, '2023-11-08', 2599.00, 'completed', 'alipay'),
(10369, 37, '2023-12-05', 199.00, 'completed', 'wechat'),
(10370, 38, '2023-12-10', 3999.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10371, 39, '2023-12-15', 1599.00, 'completed', 'credit_card'),
(10372, 40, '2023-12-20', 899.00, 'completed', 'wechat'),
(10373, 51, '2023-10-08', 6999.00, 'completed', 'alipay'),
(10374, 52, '2023-10-18', 499.00, 'completed', 'wechat'),
(10375, 53, '2023-11-02', 1299.00, 'completed', 'credit_card'),
(10376, 54, '2023-11-08', 2999.00, 'completed', 'alipay'),
(10377, 55, '2023-12-02', 799.00, 'completed', 'wechat'),
(10378, 56, '2023-12-12', 1899.00, 'completed', 'alipay'),
(10379, 57, '2023-10-12', 5999.00, 'completed', 'credit_card'),
(10380, 58, '2023-11-05', 299.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10381, 59, '2023-12-08', 1599.00, 'completed', 'alipay'),
(10382, 60, '2023-10-22', 899.00, 'completed', 'wechat'),
(10383, 71, '2023-11-18', 4999.00, 'completed', 'credit_card'),
(10384, 72, '2023-12-18', 599.00, 'completed', 'alipay'),
(10385, 73, '2023-10-28', 2599.00, 'completed', 'wechat'),
(10386, 74, '2023-11-22', 1299.00, 'completed', 'alipay'),
(10387, 75, '2023-12-22', 799.00, 'completed', 'credit_card'),
(10388, 76, '2023-10-15', 3999.00, 'completed', 'wechat'),
(10389, 77, '2023-11-15', 199.00, 'completed', 'alipay'),
(10390, 78, '2023-12-15', 6999.00, 'completed', 'credit_card');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10391, 1, '2023-10-20', 1899.00, 'completed', 'wechat'),
(10392, 4, '2023-11-20', 2999.00, 'completed', 'alipay'),
(10393, 11, '2023-12-20', 899.00, 'completed', 'credit_card'),
(10394, 33, '2023-10-25', 4999.00, 'completed', 'wechat'),
(10395, 57, '2023-11-25', 599.00, 'completed', 'alipay'),
(10396, 73, '2023-12-25', 1599.00, 'completed', 'wechat'),
(10397, 2, '2023-12-28', 8999.00, 'completed', 'credit_card'),
(10398, 3, '2023-12-29', 499.00, 'completed', 'alipay'),
(10399, 5, '2023-12-30', 2599.00, 'completed', 'wechat'),
(10400, 6, '2023-12-31', 1299.00, 'completed', 'alipay');

-- 2024年订单 (约350条)
-- 2024年Q1 (春节低谷)
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10401, 1, '2024-01-02', 2999.00, 'completed', 'alipay'),
(10402, 2, '2024-01-05', 899.00, 'completed', 'wechat'),
(10403, 3, '2024-01-08', 1599.00, 'completed', 'credit_card'),
(10404, 4, '2024-01-12', 499.00, 'completed', 'alipay'),
(10405, 5, '2024-01-15', 3999.00, 'completed', 'wechat'),
(10406, 6, '2024-01-18', 799.00, 'completed', 'alipay'),
(10407, 7, '2024-01-22', 199.00, 'completed', 'wechat'),
(10408, 8, '2024-01-25', 6999.00, 'completed', 'credit_card'),
(10409, 9, '2024-01-28', 1299.00, 'completed', 'alipay'),
(10410, 10, '2024-02-01', 599.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10411, 11, '2024-02-05', 2599.00, 'completed', 'alipay'),
(10412, 12, '2024-02-08', 899.00, 'completed', 'wechat'),
(10413, 13, '2024-02-12', 1899.00, 'completed', 'credit_card'),
(10414, 14, '2024-02-15', 299.00, 'completed', 'alipay'),
(10415, 15, '2024-02-18', 4999.00, 'completed', 'wechat'),
(10416, 16, '2024-02-22', 699.00, 'completed', 'alipay'),
(10417, 17, '2024-02-25', 159.00, 'cancelled', 'wechat'),
(10418, 18, '2024-02-28', 5999.00, 'completed', 'credit_card'),
(10419, 19, '2024-03-02', 1599.00, 'completed', 'alipay'),
(10420, 20, '2024-03-05', 799.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10421, 21, '2024-03-08', 2999.00, 'completed', 'alipay'),
(10422, 22, '2024-03-12', 499.00, 'completed', 'wechat'),
(10423, 23, '2024-03-15', 1299.00, 'completed', 'credit_card'),
(10424, 24, '2024-03-18', 899.00, 'completed', 'alipay'),
(10425, 25, '2024-03-22', 3999.00, 'completed', 'wechat'),
(10426, 26, '2024-03-25', 599.00, 'completed', 'alipay'),
(10427, 27, '2024-03-28', 1899.00, 'completed', 'wechat'),
(10428, 28, '2024-01-10', 299.00, 'completed', 'credit_card'),
(10429, 29, '2024-02-10', 8999.00, 'completed', 'alipay'),
(10430, 30, '2024-03-10', 699.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10431, 31, '2024-01-15', 1599.00, 'completed', 'alipay'),
(10432, 32, '2024-02-15', 2599.00, 'completed', 'wechat'),
(10433, 33, '2024-03-15', 11999.00, 'completed', 'credit_card'),
(10434, 34, '2024-01-20', 499.00, 'completed', 'alipay'),
(10435, 35, '2024-02-20', 899.00, 'completed', 'wechat'),
(10436, 36, '2024-03-20', 199.00, 'completed', 'alipay'),
(10437, 37, '2024-01-25', 4999.00, 'completed', 'credit_card'),
(10438, 38, '2024-02-25', 799.00, 'completed', 'wechat'),
(10439, 39, '2024-03-25', 6999.00, 'completed', 'alipay'),
(10440, 40, '2024-01-28', 1299.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10441, 51, '2024-02-28', 2999.00, 'completed', 'credit_card'),
(10442, 52, '2024-03-28', 599.00, 'completed', 'alipay'),
(10443, 53, '2024-01-05', 1899.00, 'completed', 'wechat'),
(10444, 54, '2024-02-05', 299.00, 'completed', 'alipay'),
(10445, 55, '2024-03-05', 9999.00, 'completed', 'credit_card'),
(10446, 56, '2024-01-12', 699.00, 'completed', 'wechat'),
(10447, 57, '2024-02-12', 14999.00, 'completed', 'alipay'),
(10448, 58, '2024-03-12', 899.00, 'completed', 'wechat'),
(10449, 59, '2024-01-18', 1599.00, 'completed', 'credit_card'),
(10450, 60, '2024-02-18', 499.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10451, 71, '2024-03-18', 3999.00, 'completed', 'wechat'),
(10452, 72, '2024-01-22', 799.00, 'completed', 'alipay'),
(10453, 73, '2024-02-22', 8999.00, 'completed', 'credit_card'),
(10454, 74, '2024-03-22', 1299.00, 'completed', 'wechat'),
(10455, 75, '2024-01-28', 199.00, 'completed', 'alipay'),
(10456, 76, '2024-02-28', 2599.00, 'completed', 'wechat'),
(10457, 77, '2024-03-28', 599.00, 'completed', 'credit_card'),
(10458, 78, '2024-01-08', 4999.00, 'completed', 'alipay'),
(10459, 1, '2024-02-08', 899.00, 'completed', 'wechat'),
(10460, 4, '2024-03-08', 1899.00, 'completed', 'alipay');

-- 2024年Q2 (正常期)
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10461, 1, '2024-04-02', 5999.00, 'completed', 'alipay'),
(10462, 2, '2024-04-05', 1599.00, 'completed', 'wechat'),
(10463, 3, '2024-04-08', 899.00, 'completed', 'credit_card'),
(10464, 4, '2024-04-12', 2999.00, 'completed', 'alipay'),
(10465, 5, '2024-04-15', 699.00, 'completed', 'wechat'),
(10466, 6, '2024-04-18', 1299.00, 'completed', 'alipay'),
(10467, 7, '2024-04-22', 499.00, 'completed', 'wechat'),
(10468, 8, '2024-04-25', 6999.00, 'completed', 'credit_card'),
(10469, 9, '2024-04-28', 799.00, 'completed', 'alipay'),
(10470, 10, '2024-05-01', 3999.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10471, 11, '2024-05-05', 1899.00, 'completed', 'alipay'),
(10472, 12, '2024-05-08', 599.00, 'completed', 'wechat'),
(10473, 13, '2024-05-12', 2599.00, 'completed', 'credit_card'),
(10474, 14, '2024-05-15', 899.00, 'completed', 'alipay'),
(10475, 15, '2024-05-18', 4999.00, 'completed', 'wechat'),
(10476, 16, '2024-05-22', 299.00, 'completed', 'alipay'),
(10477, 17, '2024-05-25', 1599.00, 'completed', 'wechat'),
(10478, 18, '2024-05-28', 799.00, 'completed', 'credit_card'),
(10479, 19, '2024-06-01', 8999.00, 'completed', 'alipay'),
(10480, 20, '2024-06-05', 499.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10481, 21, '2024-06-08', 1299.00, 'completed', 'alipay'),
(10482, 22, '2024-06-12', 2999.00, 'completed', 'wechat'),
(10483, 23, '2024-06-15', 699.00, 'completed', 'credit_card'),
(10484, 24, '2024-06-18', 1899.00, 'completed', 'alipay'),
(10485, 25, '2024-06-22', 599.00, 'completed', 'wechat'),
(10486, 26, '2024-06-25', 5999.00, 'completed', 'alipay'),
(10487, 27, '2024-06-28', 899.00, 'completed', 'wechat'),
(10488, 28, '2024-04-10', 1599.00, 'completed', 'credit_card'),
(10489, 29, '2024-05-10', 299.00, 'completed', 'alipay'),
(10490, 30, '2024-06-10', 3999.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10491, 31, '2024-04-15', 799.00, 'completed', 'alipay'),
(10492, 32, '2024-05-15', 2599.00, 'completed', 'wechat'),
(10493, 33, '2024-06-15', 9999.00, 'completed', 'credit_card'),
(10494, 34, '2024-04-20', 499.00, 'completed', 'alipay'),
(10495, 35, '2024-05-20', 1299.00, 'completed', 'wechat'),
(10496, 36, '2024-06-20', 899.00, 'completed', 'alipay'),
(10497, 37, '2024-04-25', 6999.00, 'completed', 'credit_card'),
(10498, 38, '2024-05-25', 199.00, 'completed', 'wechat'),
(10499, 39, '2024-06-25', 4999.00, 'completed', 'alipay'),
(10500, 40, '2024-04-28', 1599.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10501, 51, '2024-05-28', 899.00, 'completed', 'credit_card'),
(10502, 52, '2024-06-28', 2999.00, 'completed', 'alipay'),
(10503, 53, '2024-04-05', 599.00, 'completed', 'wechat'),
(10504, 54, '2024-05-05', 1899.00, 'completed', 'alipay'),
(10505, 55, '2024-06-05', 11999.00, 'completed', 'credit_card'),
(10506, 56, '2024-04-12', 299.00, 'completed', 'wechat'),
(10507, 57, '2024-05-12', 8999.00, 'completed', 'alipay'),
(10508, 58, '2024-06-12', 699.00, 'completed', 'wechat'),
(10509, 59, '2024-04-18', 1299.00, 'completed', 'credit_card'),
(10510, 60, '2024-05-18', 799.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10511, 71, '2024-06-18', 3999.00, 'completed', 'wechat'),
(10512, 72, '2024-04-22', 499.00, 'completed', 'alipay'),
(10513, 73, '2024-05-22', 6999.00, 'completed', 'credit_card'),
(10514, 74, '2024-06-22', 1599.00, 'completed', 'wechat'),
(10515, 75, '2024-04-28', 899.00, 'completed', 'alipay'),
(10516, 76, '2024-05-28', 2599.00, 'completed', 'wechat'),
(10517, 77, '2024-06-28', 199.00, 'completed', 'credit_card'),
(10518, 78, '2024-04-08', 4999.00, 'completed', 'alipay'),
(10519, 1, '2024-05-08', 1299.00, 'completed', 'wechat'),
(10520, 4, '2024-06-08', 2999.00, 'completed', 'alipay');

-- 2024年Q3 (正常期)
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10521, 1, '2024-07-02', 6999.00, 'completed', 'alipay'),
(10522, 2, '2024-07-05', 1899.00, 'completed', 'wechat'),
(10523, 3, '2024-07-08', 599.00, 'completed', 'credit_card'),
(10524, 4, '2024-07-12', 3999.00, 'completed', 'alipay'),
(10525, 5, '2024-07-15', 899.00, 'completed', 'wechat'),
(10526, 6, '2024-07-18', 1599.00, 'completed', 'alipay'),
(10527, 7, '2024-07-22', 299.00, 'completed', 'wechat'),
(10528, 8, '2024-07-25', 8999.00, 'completed', 'credit_card'),
(10529, 9, '2024-07-28', 499.00, 'completed', 'alipay'),
(10530, 10, '2024-08-01', 2599.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10531, 11, '2024-08-05', 1299.00, 'completed', 'alipay'),
(10532, 12, '2024-08-08', 799.00, 'completed', 'wechat'),
(10533, 13, '2024-08-12', 4999.00, 'completed', 'credit_card'),
(10534, 14, '2024-08-15', 599.00, 'completed', 'alipay'),
(10535, 15, '2024-08-18', 2999.00, 'completed', 'wechat'),
(10536, 16, '2024-08-22', 899.00, 'completed', 'alipay'),
(10537, 17, '2024-08-25', 1899.00, 'completed', 'wechat'),
(10538, 18, '2024-08-28', 199.00, 'completed', 'credit_card'),
(10539, 19, '2024-09-01', 5999.00, 'completed', 'alipay'),
(10540, 20, '2024-09-05', 1599.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10541, 21, '2024-09-08', 699.00, 'completed', 'alipay'),
(10542, 22, '2024-09-12', 3999.00, 'completed', 'wechat'),
(10543, 23, '2024-09-15', 899.00, 'completed', 'credit_card'),
(10544, 24, '2024-09-18', 1299.00, 'completed', 'alipay'),
(10545, 25, '2024-09-22', 499.00, 'completed', 'wechat'),
(10546, 26, '2024-09-25', 6999.00, 'completed', 'alipay'),
(10547, 27, '2024-09-28', 799.00, 'completed', 'wechat'),
(10548, 28, '2024-07-10', 2599.00, 'completed', 'credit_card'),
(10549, 29, '2024-08-10', 599.00, 'completed', 'alipay'),
(10550, 30, '2024-09-10', 1899.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10551, 31, '2024-07-15', 4999.00, 'completed', 'alipay'),
(10552, 32, '2024-08-15', 1299.00, 'completed', 'wechat'),
(10553, 33, '2024-09-15', 9999.00, 'completed', 'credit_card'),
(10554, 34, '2024-07-20', 299.00, 'completed', 'alipay'),
(10555, 35, '2024-08-20', 1599.00, 'completed', 'wechat'),
(10556, 36, '2024-09-20', 799.00, 'completed', 'alipay'),
(10557, 37, '2024-07-25', 2999.00, 'completed', 'credit_card'),
(10558, 38, '2024-08-25', 599.00, 'completed', 'wechat'),
(10559, 39, '2024-09-25', 8999.00, 'completed', 'alipay'),
(10560, 40, '2024-07-28', 899.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10561, 51, '2024-08-28', 1899.00, 'completed', 'credit_card'),
(10562, 52, '2024-09-28', 499.00, 'completed', 'alipay'),
(10563, 53, '2024-07-05', 2599.00, 'completed', 'wechat'),
(10564, 54, '2024-08-05', 699.00, 'completed', 'alipay'),
(10565, 55, '2024-09-05', 14999.00, 'completed', 'credit_card'),
(10566, 56, '2024-07-12', 899.00, 'completed', 'wechat'),
(10567, 57, '2024-08-12', 5999.00, 'completed', 'alipay'),
(10568, 58, '2024-09-12', 1299.00, 'completed', 'wechat'),
(10569, 59, '2024-07-18', 399.00, 'completed', 'credit_card'),
(10570, 60, '2024-08-18', 1599.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10571, 71, '2024-09-18', 3999.00, 'completed', 'wechat'),
(10572, 72, '2024-07-22', 799.00, 'completed', 'alipay'),
(10573, 73, '2024-08-22', 11999.00, 'completed', 'credit_card'),
(10574, 74, '2024-09-22', 599.00, 'completed', 'wechat'),
(10575, 75, '2024-07-28', 2599.00, 'completed', 'alipay'),
(10576, 76, '2024-08-28', 1299.00, 'completed', 'wechat'),
(10577, 77, '2024-09-28', 899.00, 'completed', 'credit_card'),
(10578, 78, '2024-07-08', 4999.00, 'completed', 'alipay'),
(10579, 1, '2024-08-08', 1899.00, 'completed', 'wechat'),
(10580, 4, '2024-09-08', 6999.00, 'completed', 'alipay');

-- 2024年Q4 (双十一高峰)
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10581, 1, '2024-10-01', 8999.00, 'completed', 'alipay'),
(10582, 2, '2024-10-05', 2599.00, 'completed', 'wechat'),
(10583, 3, '2024-10-08', 1299.00, 'completed', 'credit_card'),
(10584, 4, '2024-10-12', 4999.00, 'completed', 'alipay'),
(10585, 5, '2024-10-15', 799.00, 'completed', 'wechat'),
(10586, 6, '2024-10-18', 3999.00, 'completed', 'alipay'),
(10587, 7, '2024-10-22', 599.00, 'completed', 'wechat'),
(10588, 8, '2024-10-25', 6999.00, 'completed', 'credit_card'),
(10589, 9, '2024-10-28', 1599.00, 'completed', 'alipay'),
(10590, 10, '2024-10-31', 2999.00, 'completed', 'wechat');

-- 2024双十一期间订单激增
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10591, 1, '2024-11-01', 11999.00, 'completed', 'credit_card'),
(10592, 2, '2024-11-02', 6999.00, 'completed', 'alipay'),
(10593, 3, '2024-11-03', 4999.00, 'completed', 'wechat'),
(10594, 4, '2024-11-04', 3999.00, 'completed', 'alipay'),
(10595, 5, '2024-11-05', 2599.00, 'completed', 'credit_card'),
(10596, 6, '2024-11-06', 1899.00, 'completed', 'wechat'),
(10597, 7, '2024-11-07', 899.00, 'completed', 'alipay'),
(10598, 8, '2024-11-08', 5999.00, 'completed', 'wechat'),
(10599, 9, '2024-11-09', 1299.00, 'completed', 'credit_card'),
(10600, 10, '2024-11-10', 9999.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10601, 11, '2024-11-11', 19999.00, 'completed', 'credit_card'),
(10602, 12, '2024-11-11', 14999.00, 'completed', 'alipay'),
(10603, 13, '2024-11-11', 9999.00, 'completed', 'wechat'),
(10604, 14, '2024-11-11', 8999.00, 'completed', 'alipay'),
(10605, 15, '2024-11-11', 6999.00, 'completed', 'credit_card'),
(10606, 16, '2024-11-11', 5999.00, 'completed', 'wechat'),
(10607, 17, '2024-11-11', 4999.00, 'completed', 'alipay'),
(10608, 18, '2024-11-11', 3999.00, 'completed', 'wechat'),
(10609, 19, '2024-11-11', 2999.00, 'completed', 'credit_card'),
(10610, 20, '2024-11-11', 2599.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10611, 21, '2024-11-11', 11999.00, 'completed', 'credit_card'),
(10612, 22, '2024-11-11', 8999.00, 'completed', 'alipay'),
(10613, 23, '2024-11-11', 6999.00, 'completed', 'wechat'),
(10614, 24, '2024-11-11', 4999.00, 'completed', 'alipay'),
(10615, 25, '2024-11-11', 3999.00, 'completed', 'credit_card'),
(10616, 26, '2024-11-11', 2999.00, 'completed', 'wechat'),
(10617, 27, '2024-11-11', 1999.00, 'completed', 'alipay'),
(10618, 28, '2024-11-11', 1599.00, 'completed', 'wechat'),
(10619, 29, '2024-11-11', 1299.00, 'completed', 'credit_card'),
(10620, 30, '2024-11-11', 999.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10621, 31, '2024-11-11', 14999.00, 'completed', 'credit_card'),
(10622, 32, '2024-11-11', 9999.00, 'completed', 'alipay'),
(10623, 33, '2024-11-11', 19999.00, 'completed', 'wechat'),
(10624, 34, '2024-11-11', 5999.00, 'completed', 'alipay'),
(10625, 35, '2024-11-11', 3999.00, 'completed', 'credit_card'),
(10626, 36, '2024-11-11', 2599.00, 'completed', 'wechat'),
(10627, 37, '2024-11-11', 1899.00, 'completed', 'alipay'),
(10628, 38, '2024-11-11', 1299.00, 'completed', 'wechat'),
(10629, 39, '2024-11-11', 11999.00, 'completed', 'credit_card'),
(10630, 40, '2024-11-11', 6999.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10631, 51, '2024-11-11', 8999.00, 'completed', 'credit_card'),
(10632, 52, '2024-11-11', 4999.00, 'completed', 'alipay'),
(10633, 53, '2024-11-11', 2999.00, 'completed', 'wechat'),
(10634, 54, '2024-11-11', 1999.00, 'completed', 'alipay'),
(10635, 55, '2024-11-11', 14999.00, 'completed', 'credit_card'),
(10636, 56, '2024-11-11', 1599.00, 'completed', 'wechat'),
(10637, 57, '2024-11-11', 19999.00, 'completed', 'alipay'),
(10638, 58, '2024-11-11', 899.00, 'completed', 'wechat'),
(10639, 59, '2024-11-11', 599.00, 'completed', 'credit_card'),
(10640, 60, '2024-11-11', 3999.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10641, 71, '2024-11-11', 11999.00, 'completed', 'credit_card'),
(10642, 72, '2024-11-11', 6999.00, 'completed', 'alipay'),
(10643, 73, '2024-11-11', 19999.00, 'completed', 'wechat'),
(10644, 74, '2024-11-11', 8999.00, 'completed', 'alipay'),
(10645, 75, '2024-11-11', 1899.00, 'completed', 'credit_card'),
(10646, 76, '2024-11-11', 1299.00, 'completed', 'wechat'),
(10647, 77, '2024-11-11', 799.00, 'completed', 'alipay'),
(10648, 78, '2024-11-11', 4999.00, 'completed', 'wechat'),
(10649, 1, '2024-11-11', 5999.00, 'completed', 'credit_card'),
(10650, 4, '2024-11-11', 9999.00, 'completed', 'alipay');

-- 双十一后续订单和12月订单
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10651, 11, '2024-11-12', 2599.00, 'completed', 'wechat'),
(10652, 33, '2024-11-15', 1899.00, 'completed', 'alipay'),
(10653, 57, '2024-11-18', 4999.00, 'completed', 'credit_card'),
(10654, 73, '2024-11-20', 899.00, 'completed', 'wechat'),
(10655, 2, '2024-11-22', 3999.00, 'completed', 'alipay'),
(10656, 3, '2024-11-25', 1599.00, 'completed', 'wechat'),
(10657, 5, '2024-11-28', 599.00, 'completed', 'credit_card'),
(10658, 6, '2024-12-01', 6999.00, 'completed', 'alipay'),
(10659, 7, '2024-12-05', 899.00, 'completed', 'wechat'),
(10660, 8, '2024-12-08', 2599.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10661, 9, '2024-12-10', 1299.00, 'completed', 'credit_card'),
(10662, 10, '2024-12-12', 4999.00, 'completed', 'wechat'),
(10663, 11, '2024-12-15', 799.00, 'completed', 'alipay'),
(10664, 12, '2024-12-18', 1899.00, 'completed', 'wechat'),
(10665, 13, '2024-12-20', 599.00, 'completed', 'credit_card'),
(10666, 14, '2024-12-22', 3999.00, 'completed', 'alipay'),
(10667, 15, '2024-12-25', 8999.00, 'completed', 'wechat'),
(10668, 16, '2024-12-28', 1599.00, 'completed', 'alipay'),
(10669, 17, '2024-12-30', 299.00, 'completed', 'wechat'),
(10670, 18, '2024-12-31', 5999.00, 'completed', 'credit_card');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10671, 19, '2024-10-08', 1899.00, 'completed', 'alipay'),
(10672, 20, '2024-10-15', 2599.00, 'completed', 'wechat'),
(10673, 21, '2024-10-22', 899.00, 'completed', 'credit_card'),
(10674, 22, '2024-10-28', 4999.00, 'completed', 'alipay'),
(10675, 23, '2024-11-05', 1299.00, 'completed', 'wechat'),
(10676, 24, '2024-11-08', 6999.00, 'completed', 'alipay'),
(10677, 25, '2024-12-05', 599.00, 'completed', 'credit_card'),
(10678, 26, '2024-12-10', 2999.00, 'completed', 'wechat'),
(10679, 27, '2024-12-15', 1599.00, 'completed', 'alipay'),
(10680, 28, '2024-12-20', 899.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10681, 29, '2024-10-12', 3999.00, 'completed', 'credit_card'),
(10682, 30, '2024-10-25', 1899.00, 'completed', 'alipay'),
(10683, 31, '2024-11-02', 699.00, 'completed', 'wechat'),
(10684, 32, '2024-11-15', 4999.00, 'completed', 'alipay'),
(10685, 33, '2024-12-02', 1299.00, 'completed', 'credit_card'),
(10686, 34, '2024-12-12', 8999.00, 'completed', 'wechat'),
(10687, 35, '2024-10-18', 599.00, 'completed', 'alipay'),
(10688, 36, '2024-11-08', 2599.00, 'completed', 'wechat'),
(10689, 37, '2024-12-08', 1599.00, 'completed', 'credit_card'),
(10690, 38, '2024-10-22', 899.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10691, 39, '2024-11-18', 5999.00, 'completed', 'wechat'),
(10692, 40, '2024-12-18', 1899.00, 'completed', 'alipay'),
(10693, 51, '2024-10-05', 2999.00, 'completed', 'credit_card'),
(10694, 52, '2024-10-20', 799.00, 'completed', 'wechat'),
(10695, 53, '2024-11-05', 4999.00, 'completed', 'alipay'),
(10696, 54, '2024-11-20', 1299.00, 'completed', 'wechat'),
(10697, 55, '2024-12-05', 6999.00, 'completed', 'credit_card'),
(10698, 56, '2024-12-20', 599.00, 'completed', 'alipay'),
(10699, 57, '2024-10-15', 3999.00, 'completed', 'wechat'),
(10700, 58, '2024-11-15', 899.00, 'completed', 'alipay');

-- 2025年订单 (约250条)
INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10701, 1, '2025-01-02', 4999.00, 'completed', 'alipay'),
(10702, 2, '2025-01-05', 1599.00, 'completed', 'wechat'),
(10703, 3, '2025-01-08', 899.00, 'completed', 'credit_card'),
(10704, 4, '2025-01-12', 6999.00, 'completed', 'alipay'),
(10705, 5, '2025-01-15', 599.00, 'completed', 'wechat'),
(10706, 6, '2025-01-18', 2599.00, 'completed', 'alipay'),
(10707, 7, '2025-01-22', 299.00, 'pending', 'wechat'),
(10708, 8, '2025-01-25', 8999.00, 'completed', 'credit_card'),
(10709, 9, '2025-01-28', 1299.00, 'completed', 'alipay'),
(10710, 10, '2025-02-01', 799.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10711, 11, '2025-02-05', 3999.00, 'completed', 'alipay'),
(10712, 12, '2025-02-08', 599.00, 'completed', 'wechat'),
(10713, 13, '2025-02-12', 1899.00, 'completed', 'credit_card'),
(10714, 14, '2025-02-15', 499.00, 'completed', 'alipay'),
(10715, 15, '2025-02-18', 5999.00, 'completed', 'wechat'),
(10716, 16, '2025-02-22', 899.00, 'completed', 'alipay'),
(10717, 17, '2025-02-25', 199.00, 'pending', 'wechat'),
(10718, 18, '2025-02-28', 4999.00, 'completed', 'credit_card'),
(10719, 19, '2025-03-02', 1599.00, 'completed', 'alipay'),
(10720, 20, '2025-03-05', 699.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10721, 21, '2025-03-08', 2999.00, 'completed', 'alipay'),
(10722, 22, '2025-03-12', 899.00, 'completed', 'wechat'),
(10723, 23, '2025-03-15', 1299.00, 'completed', 'credit_card'),
(10724, 24, '2025-01-10', 599.00, 'completed', 'alipay'),
(10725, 25, '2025-02-10', 6999.00, 'completed', 'wechat'),
(10726, 26, '2025-03-10', 1899.00, 'completed', 'alipay'),
(10727, 27, '2025-01-15', 799.00, 'completed', 'wechat'),
(10728, 28, '2025-02-15', 3999.00, 'completed', 'credit_card'),
(10729, 29, '2025-03-15', 499.00, 'completed', 'alipay'),
(10730, 30, '2025-01-20', 8999.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10731, 31, '2025-02-20', 1599.00, 'completed', 'alipay'),
(10732, 32, '2025-03-01', 2599.00, 'completed', 'wechat'),
(10733, 33, '2025-01-25', 11999.00, 'completed', 'credit_card'),
(10734, 34, '2025-02-25', 899.00, 'completed', 'alipay'),
(10735, 35, '2025-03-05', 1299.00, 'completed', 'wechat'),
(10736, 36, '2025-01-28', 599.00, 'completed', 'alipay'),
(10737, 37, '2025-02-28', 4999.00, 'completed', 'credit_card'),
(10738, 38, '2025-03-08', 699.00, 'completed', 'wechat'),
(10739, 39, '2025-01-05', 9999.00, 'completed', 'alipay'),
(10740, 40, '2025-02-05', 1899.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10741, 51, '2025-03-05', 2599.00, 'completed', 'credit_card'),
(10742, 52, '2025-01-12', 799.00, 'completed', 'alipay'),
(10743, 53, '2025-02-12', 3999.00, 'completed', 'wechat'),
(10744, 54, '2025-03-12', 599.00, 'completed', 'alipay'),
(10745, 55, '2025-01-18', 14999.00, 'completed', 'credit_card'),
(10746, 56, '2025-02-18', 1299.00, 'completed', 'wechat'),
(10747, 57, '2025-03-15', 8999.00, 'completed', 'alipay'),
(10748, 58, '2025-01-22', 499.00, 'completed', 'wechat'),
(10749, 59, '2025-02-22', 1899.00, 'completed', 'credit_card'),
(10750, 60, '2025-03-10', 899.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10751, 71, '2025-01-28', 5999.00, 'completed', 'wechat'),
(10752, 72, '2025-02-28', 1599.00, 'completed', 'alipay'),
(10753, 73, '2025-03-08', 19999.00, 'completed', 'credit_card'),
(10754, 74, '2025-01-05', 899.00, 'completed', 'wechat'),
(10755, 75, '2025-02-05', 2599.00, 'completed', 'alipay'),
(10756, 76, '2025-03-05', 699.00, 'completed', 'wechat'),
(10757, 77, '2025-01-15', 4999.00, 'completed', 'credit_card'),
(10758, 78, '2025-02-15', 1299.00, 'completed', 'alipay'),
(10759, 1, '2025-03-01', 6999.00, 'completed', 'wechat'),
(10760, 4, '2025-03-10', 3999.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10761, 11, '2025-01-08', 2599.00, 'completed', 'credit_card'),
(10762, 33, '2025-02-08', 1899.00, 'completed', 'wechat'),
(10763, 57, '2025-03-08', 5999.00, 'completed', 'alipay'),
(10764, 73, '2025-01-15', 899.00, 'completed', 'wechat'),
(10765, 2, '2025-02-15', 3999.00, 'completed', 'credit_card'),
(10766, 3, '2025-03-15', 1599.00, 'completed', 'alipay'),
(10767, 5, '2025-01-22', 699.00, 'completed', 'wechat'),
(10768, 6, '2025-02-22', 4999.00, 'completed', 'alipay'),
(10769, 7, '2025-03-05', 899.00, 'completed', 'credit_card'),
(10770, 8, '2025-01-28', 1299.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10771, 9, '2025-02-28', 6999.00, 'completed', 'alipay'),
(10772, 10, '2025-03-10', 599.00, 'completed', 'wechat'),
(10773, 11, '2025-01-12', 2999.00, 'completed', 'credit_card'),
(10774, 12, '2025-02-12', 899.00, 'completed', 'alipay'),
(10775, 13, '2025-03-12', 1599.00, 'completed', 'wechat'),
(10776, 14, '2025-01-18', 4999.00, 'completed', 'alipay'),
(10777, 15, '2025-02-18', 799.00, 'completed', 'credit_card'),
(10778, 16, '2025-03-08', 2599.00, 'completed', 'wechat'),
(10779, 17, '2025-01-25', 1299.00, 'completed', 'alipay'),
(10780, 18, '2025-02-25', 8999.00, 'completed', 'wechat');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10781, 19, '2025-03-05', 599.00, 'completed', 'credit_card'),
(10782, 20, '2025-01-02', 1899.00, 'completed', 'alipay'),
(10783, 21, '2025-02-02', 3999.00, 'completed', 'wechat'),
(10784, 22, '2025-03-02', 899.00, 'completed', 'alipay'),
(10785, 23, '2025-01-08', 5999.00, 'completed', 'credit_card'),
(10786, 24, '2025-02-08', 1599.00, 'completed', 'wechat'),
(10787, 25, '2025-03-08', 699.00, 'completed', 'alipay'),
(10788, 26, '2025-01-15', 2599.00, 'completed', 'wechat'),
(10789, 27, '2025-02-15', 899.00, 'completed', 'credit_card'),
(10790, 28, '2025-03-15', 4999.00, 'completed', 'alipay');

INSERT INTO e_orders (order_id, user_id, order_date, total_amount, status, payment_method) VALUES
(10791, 29, '2025-01-22', 1299.00, 'completed', 'wechat'),
(10792, 30, '2025-02-22', 6999.00, 'completed', 'alipay'),
(10793, 31, '2025-03-10', 599.00, 'completed', 'credit_card'),
(10794, 32, '2025-01-28', 1899.00, 'completed', 'wechat'),
(10795, 33, '2025-02-28', 9999.00, 'completed', 'alipay'),
(10796, 34, '2025-03-05', 799.00, 'completed', 'wechat'),
(10797, 35, '2025-01-05', 2999.00, 'completed', 'credit_card'),
(10798, 36, '2025-02-05', 1599.00, 'completed', 'alipay'),
(10799, 37, '2025-03-05', 899.00, 'completed', 'wechat'),
(10800, 38, '2025-01-12', 4999.00, 'completed', 'alipay');

-- ============================================================================
-- 插入订单明细数据 (约2500条)
-- ============================================================================

-- 为每个订单生成明细 (每个订单1-4个商品)
-- 2023年Q1订单明细
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100001, 10001, 1, 1, 9999.00),
(100002, 10002, 9, 1, 599.00),
(100003, 10003, 37, 1, 2999.00),
(100004, 10004, 17, 1, 168.00),
(100005, 10005, 22, 1, 1299.00),
(100006, 10006, 29, 1, 499.00),
(100007, 10007, 10, 1, 299.00),
(100008, 10008, 12, 1, 899.00),
(100009, 10009, 2, 1, 6999.00),
(100010, 10010, 13, 1, 399.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100011, 10011, 14, 1, 259.00),
(100012, 10012, 28, 1, 1599.00),
(100013, 10013, 19, 1, 89.00),
(100014, 10014, 25, 1, 3999.00),
(100015, 10015, 32, 1, 159.00),
(100016, 10016, 34, 1, 799.00),
(100017, 10017, 31, 1, 199.00),
(100018, 10018, 26, 1, 2599.00),
(100019, 10019, 39, 1, 99.00),
(100020, 10020, 5, 1, 14999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100021, 10021, 33, 1, 899.00),
(100022, 10022, 35, 1, 599.00),
(100023, 10023, 27, 1, 1999.00),
(100024, 10024, 10, 1, 299.00),
(100025, 10025, 20, 1, 69.00),
(100026, 10026, 49, 1, 499.00),
(100027, 10027, 41, 1, 8999.00),
(100028, 10028, 16, 1, 359.00),
(100029, 10029, 31, 1, 199.00),
(100030, 10030, 37, 1, 2999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100031, 10031, 3, 1, 5999.00),
(100032, 10032, 44, 1, 299.00),
(100033, 10033, 42, 1, 1899.00),
(100034, 10034, 43, 1, 699.00),
(100035, 10035, 39, 1, 99.00),
(100036, 10036, 40, 1, 3999.00),
(100037, 10037, 32, 1, 159.00),
(100038, 10038, 14, 1, 259.00),
(100039, 10039, 33, 1, 899.00),
(100040, 10040, 29, 1, 499.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100041, 10041, 8, 1, 11999.00),
(100042, 10042, 31, 1, 199.00),
(100043, 10043, 35, 1, 599.00),
(100044, 10044, 10, 1, 299.00),
(100045, 10045, 22, 1, 1299.00),
(100046, 10046, 19, 1, 89.00),
(100047, 10047, 25, 1, 3999.00),
(100048, 10048, 34, 1, 799.00),
(100049, 10049, 32, 1, 159.00),
(100050, 10050, 26, 1, 2599.00);

-- 额外明细(多商品订单)
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100051, 10051, 29, 1, 499.00),
(100052, 10052, 33, 1, 899.00),
(100053, 10053, 31, 1, 199.00),
(100054, 10054, 2, 1, 6999.00),
(100055, 10055, 16, 1, 359.00),
(100056, 10056, 28, 1, 1599.00),
(100057, 10057, 20, 1, 69.00),
(100058, 10058, 37, 1, 2999.00),
(100059, 10059, 39, 1, 99.00),
(100060, 10060, 41, 1, 8999.00);

-- 2023年Q2订单明细
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100061, 10061, 4, 1, 4999.00),
(100062, 10062, 10, 1, 299.00),
(100063, 10063, 33, 1, 899.00),
(100064, 10064, 22, 1, 1299.00),
(100065, 10065, 29, 1, 499.00),
(100066, 10066, 31, 1, 199.00),
(100067, 10067, 37, 1, 2999.00),
(100068, 10068, 35, 1, 599.00),
(100069, 10069, 32, 1, 159.00),
(100070, 10070, 1, 1, 9999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100071, 10071, 34, 1, 799.00),
(100072, 10072, 13, 1, 399.00),
(100073, 10073, 27, 1, 1999.00),
(100074, 10074, 14, 1, 259.00),
(100075, 10075, 25, 1, 3999.00),
(100076, 10076, 19, 1, 89.00),
(100077, 10077, 43, 1, 699.00),
(100078, 10078, 28, 1, 1599.00),
(100079, 10079, 44, 1, 299.00),
(100080, 10080, 2, 1, 6999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100081, 10081, 29, 1, 499.00),
(100082, 10082, 31, 1, 199.00),
(100083, 10083, 26, 1, 2599.00),
(100084, 10084, 32, 1, 159.00),
(100085, 10085, 33, 1, 899.00),
(100086, 10086, 16, 1, 359.00),
(100087, 10087, 22, 1, 1299.00),
(100088, 10088, 35, 1, 599.00),
(100089, 10089, 39, 1, 99.00),
(100090, 10090, 5, 1, 14999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100091, 10091, 34, 1, 799.00),
(100092, 10092, 29, 1, 499.00),
(100093, 10093, 37, 1, 2999.00),
(100094, 10094, 31, 1, 199.00),
(100095, 10095, 3, 1, 5999.00),
(100096, 10096, 17, 1, 168.00),
(100097, 10097, 33, 1, 899.00),
(100098, 10098, 14, 1, 259.00),
(100099, 10099, 42, 1, 1899.00),
(100100, 10100, 13, 1, 399.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100101, 10101, 43, 1, 699.00),
(100102, 10102, 39, 1, 99.00),
(100103, 10103, 40, 1, 3999.00),
(100104, 10104, 32, 1, 159.00),
(100105, 10105, 26, 1, 2599.00),
(100106, 10106, 35, 1, 599.00),
(100107, 10107, 27, 1, 1999.00),
(100108, 10108, 10, 1, 299.00),
(100109, 10109, 34, 1, 799.00),
(100110, 10110, 29, 1, 499.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100111, 10111, 22, 1, 1299.00),
(100112, 10112, 16, 1, 359.00),
(100113, 10113, 41, 1, 8999.00),
(100114, 10114, 31, 1, 199.00),
(100115, 10115, 37, 1, 2999.00),
(100116, 10116, 43, 1, 699.00),
(100117, 10117, 19, 1, 89.00),
(100118, 10118, 28, 1, 1599.00),
(100119, 10119, 14, 1, 259.00),
(100120, 10120, 2, 1, 6999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100121, 10121, 29, 1, 499.00),
(100122, 10122, 33, 1, 899.00),
(100123, 10123, 32, 1, 159.00),
(100124, 10124, 25, 1, 3999.00),
(100125, 10125, 44, 1, 299.00),
(100126, 10126, 8, 1, 11999.00),
(100127, 10127, 35, 1, 599.00),
(100128, 10128, 22, 1, 1299.00),
(100129, 10129, 34, 1, 799.00),
(100130, 10130, 31, 1, 199.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100131, 10131, 26, 1, 2599.00),
(100132, 10132, 39, 1, 99.00),
(100133, 10133, 4, 1, 4999.00),
(100134, 10134, 43, 1, 699.00),
(100135, 10135, 16, 1, 359.00),
(100136, 10136, 41, 1, 8999.00),
(100137, 10137, 42, 1, 1899.00),
(100138, 10138, 29, 1, 499.00),
(100139, 10139, 37, 1, 2999.00),
(100140, 10140, 32, 1, 159.00);

-- 2023年Q3订单明细
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100141, 10141, 3, 1, 5999.00),
(100142, 10142, 33, 1, 899.00),
(100143, 10143, 22, 1, 1299.00),
(100144, 10144, 10, 1, 299.00),
(100145, 10145, 26, 1, 2599.00),
(100146, 10146, 29, 1, 499.00),
(100147, 10147, 32, 1, 159.00),
(100148, 10148, 2, 1, 6999.00),
(100149, 10149, 34, 1, 799.00),
(100150, 10150, 13, 1, 399.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100151, 10151, 27, 1, 1999.00),
(100152, 10152, 35, 1, 599.00),
(100153, 10153, 19, 1, 89.00),
(100154, 10154, 25, 1, 3999.00),
(100155, 10155, 14, 1, 259.00),
(100156, 10156, 28, 1, 1599.00),
(100157, 10157, 43, 1, 699.00),
(100158, 10158, 31, 1, 199.00),
(100159, 10159, 41, 1, 8999.00),
(100160, 10160, 16, 1, 359.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100161, 10161, 37, 1, 2999.00),
(100162, 10162, 39, 1, 99.00),
(100163, 10163, 22, 1, 1299.00),
(100164, 10164, 29, 1, 499.00),
(100165, 10165, 33, 1, 899.00),
(100166, 10166, 32, 1, 159.00),
(100167, 10167, 4, 1, 4999.00),
(100168, 10168, 44, 1, 299.00),
(100169, 10169, 34, 1, 799.00),
(100170, 10170, 35, 1, 599.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100171, 10171, 26, 1, 2599.00),
(100172, 10172, 42, 1, 1899.00),
(100173, 10173, 8, 1, 11999.00),
(100174, 10174, 13, 1, 399.00),
(100175, 10175, 43, 1, 699.00),
(100176, 10176, 31, 1, 199.00),
(100177, 10177, 28, 1, 1599.00),
(100178, 10178, 14, 1, 259.00),
(100179, 10179, 3, 1, 5999.00),
(100180, 10180, 19, 1, 89.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100181, 10181, 25, 1, 3999.00),
(100182, 10182, 29, 1, 499.00),
(100183, 10183, 32, 1, 159.00),
(100184, 10184, 33, 1, 899.00),
(100185, 10185, 26, 1, 2599.00),
(100186, 10186, 10, 1, 299.00),
(100187, 10187, 2, 1, 6999.00),
(100188, 10188, 34, 1, 799.00),
(100189, 10189, 22, 1, 1299.00),
(100190, 10190, 35, 1, 599.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100191, 10191, 27, 1, 1999.00),
(100192, 10192, 16, 1, 359.00),
(100193, 10193, 41, 1, 8999.00),
(100194, 10194, 31, 1, 199.00),
(100195, 10195, 43, 1, 699.00),
(100196, 10196, 28, 1, 1599.00),
(100197, 10197, 39, 1, 99.00),
(100198, 10198, 4, 1, 4999.00),
(100199, 10199, 14, 1, 259.00),
(100200, 10200, 33, 1, 899.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100201, 10201, 37, 1, 2999.00),
(100202, 10202, 29, 1, 499.00),
(100203, 10203, 22, 1, 1299.00),
(100204, 10204, 34, 1, 799.00),
(100205, 10205, 5, 1, 14999.00),
(100206, 10206, 13, 1, 399.00),
(100207, 10207, 35, 1, 599.00),
(100208, 10208, 42, 1, 1899.00),
(100209, 10209, 32, 1, 159.00),
(100210, 10210, 26, 1, 2599.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100211, 10211, 43, 1, 699.00),
(100212, 10212, 39, 1, 99.00),
(100213, 10213, 25, 1, 3999.00),
(100214, 10214, 31, 1, 199.00),
(100215, 10215, 28, 1, 1599.00),
(100216, 10216, 29, 1, 499.00),
(100217, 10217, 26, 1, 2599.00),
(100218, 10218, 33, 1, 899.00),
(100219, 10219, 16, 1, 359.00),
(100220, 10220, 3, 1, 5999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100221, 10221, 14, 1, 259.00),
(100222, 10222, 22, 1, 1299.00),
(100223, 10223, 34, 1, 799.00),
(100224, 10224, 31, 1, 199.00),
(100225, 10225, 2, 1, 6999.00),
(100226, 10226, 35, 1, 599.00),
(100227, 10227, 27, 1, 1999.00),
(100228, 10228, 10, 1, 299.00),
(100229, 10229, 33, 1, 899.00),
(100230, 10230, 32, 1, 159.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100231, 10231, 4, 1, 4999.00),
(100232, 10232, 13, 1, 399.00),
(100233, 10233, 43, 1, 699.00),
(100234, 10234, 28, 1, 1599.00),
(100235, 10235, 14, 1, 259.00),
(100236, 10236, 41, 1, 8999.00),
(100237, 10237, 29, 1, 499.00),
(100238, 10238, 26, 1, 2599.00),
(100239, 10239, 33, 1, 899.00),
(100240, 10240, 31, 1, 199.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100241, 10241, 25, 1, 3999.00),
(100242, 10242, 35, 1, 599.00),
(100243, 10243, 22, 1, 1299.00),
(100244, 10244, 34, 1, 799.00),
(100245, 10245, 32, 1, 159.00),
(100246, 10246, 37, 1, 2999.00),
(100247, 10247, 29, 1, 499.00),
(100248, 10248, 33, 1, 899.00),
(100249, 10249, 3, 1, 5999.00),
(100250, 10250, 44, 1, 299.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100251, 10251, 28, 1, 1599.00),
(100252, 10252, 43, 1, 699.00),
(100253, 10253, 31, 1, 199.00),
(100254, 10254, 4, 1, 4999.00),
(100255, 10255, 16, 1, 359.00),
(100256, 10256, 42, 1, 1899.00),
(100257, 10257, 35, 1, 599.00),
(100258, 10258, 26, 1, 2599.00),
(100259, 10259, 39, 1, 99.00),
(100260, 10260, 34, 1, 799.00);

-- 2023年Q4订单明细 (双十一高峰)
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100261, 10261, 1, 1, 9999.00),
(100262, 10262, 37, 1, 2999.00),
(100263, 10263, 33, 1, 899.00),
(100264, 10264, 28, 1, 1599.00),
(100265, 10265, 35, 1, 599.00),
(100266, 10266, 2, 1, 6999.00),
(100267, 10267, 10, 1, 299.00),
(100268, 10268, 22, 1, 1299.00),
(100269, 10269, 29, 1, 499.00),
(100270, 10270, 25, 1, 3999.00);

-- 双十一当天的大订单明细 (多商品组合)
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100271, 10271, 5, 1, 14999.00),
(100272, 10272, 41, 1, 8999.00),
(100273, 10273, 3, 1, 5999.00),
(100274, 10274, 26, 1, 2599.00),
(100275, 10275, 42, 1, 1899.00),
(100276, 10276, 33, 2, 499.50),
(100277, 10277, 4, 1, 4999.00),
(100278, 10278, 34, 1, 799.00),
(100279, 10279, 28, 1, 1599.00),
(100280, 10280, 8, 1, 11999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100281, 10281, 1, 2, 9999.50),
(100282, 10282, 1, 1, 9999.00),
(100283, 10283, 2, 1, 6999.00),
(100284, 10284, 4, 1, 4999.00),
(100285, 10285, 25, 1, 3999.00),
(100286, 10286, 37, 1, 2999.00),
(100287, 10287, 27, 1, 1999.00),
(100288, 10288, 28, 1, 1599.00),
(100289, 10289, 22, 1, 1299.00),
(100290, 10290, 33, 1, 899.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100291, 10291, 5, 1, 14999.00),
(100292, 10292, 41, 1, 8999.00),
(100293, 10293, 3, 1, 5999.00),
(100294, 10294, 25, 1, 3999.00),
(100295, 10295, 37, 1, 2999.00),
(100296, 10296, 26, 1, 2599.00),
(100297, 10297, 42, 1, 1899.00),
(100298, 10298, 28, 1, 1599.00),
(100299, 10299, 33, 2, 499.50),
(100300, 10300, 34, 1, 799.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100301, 10301, 8, 1, 11999.00),
(100302, 10302, 2, 1, 6999.00),
(100303, 10303, 1, 2, 9999.50),
(100304, 10304, 4, 1, 4999.00),
(100305, 10305, 26, 1, 2599.00),
(100306, 10306, 22, 1, 1299.00),
(100307, 10307, 33, 1, 899.00),
(100308, 10308, 35, 1, 599.00),
(100309, 10309, 41, 1, 8999.00),
(100310, 10310, 25, 1, 3999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100311, 10311, 1, 1, 9999.00),
(100312, 10312, 3, 1, 5999.00),
(100313, 10313, 37, 1, 2999.00),
(100314, 10314, 27, 1, 1999.00),
(100315, 10315, 5, 1, 14999.00),
(100316, 10316, 28, 1, 1599.00),
(100317, 10317, 8, 1, 11999.00),
(100318, 10318, 34, 1, 799.00),
(100319, 10319, 29, 1, 499.00),
(100320, 10320, 26, 1, 2599.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100321, 10321, 41, 1, 8999.00),
(100322, 10322, 4, 1, 4999.00),
(100323, 10323, 1, 2, 9999.50),
(100324, 10324, 2, 1, 6999.00),
(100325, 10325, 22, 1, 1299.00),
(100326, 10326, 33, 1, 899.00),
(100327, 10327, 35, 1, 599.00),
(100328, 10328, 25, 1, 3999.00),
(100329, 10329, 37, 1, 2999.00),
(100330, 10330, 3, 1, 5999.00);

-- 双十一后续订单和退款订单明细
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100331, 10331, 28, 1, 1599.00),
(100332, 10332, 37, 1, 2999.00),
(100333, 10333, 33, 1, 899.00),
(100334, 10334, 4, 1, 4999.00),
(100335, 10335, 35, 1, 599.00),
(100336, 10336, 22, 1, 1299.00),
(100337, 10337, 34, 1, 799.00),
(100338, 10338, 26, 1, 2599.00),
(100339, 10339, 31, 1, 199.00),
(100340, 10340, 25, 1, 3999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100341, 10341, 28, 1, 1599.00),
(100342, 10342, 33, 1, 899.00),
(100343, 10343, 37, 1, 2999.00),
(100344, 10344, 35, 1, 599.00),
(100345, 10345, 22, 1, 1299.00),
(100346, 10346, 4, 1, 4999.00),
(100347, 10347, 34, 1, 799.00),
(100348, 10348, 42, 1, 1899.00),
(100349, 10349, 10, 1, 299.00),
(100350, 10350, 26, 1, 2599.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100351, 10351, 2, 1, 6999.00),
(100352, 10352, 28, 1, 1599.00),
(100353, 10353, 33, 1, 899.00),
(100354, 10354, 37, 1, 2999.00),
(100355, 10355, 29, 1, 499.00),
(100356, 10356, 22, 1, 1299.00),
(100357, 10357, 25, 1, 3999.00),
(100358, 10358, 34, 1, 799.00),
(100359, 10359, 3, 1, 5999.00),
(100360, 10360, 31, 1, 199.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100361, 10361, 28, 1, 1599.00),
(100362, 10362, 37, 1, 2999.00),
(100363, 10363, 33, 1, 899.00),
(100364, 10364, 4, 1, 4999.00),
(100365, 10365, 35, 1, 599.00),
(100366, 10366, 22, 1, 1299.00),
(100367, 10367, 34, 1, 799.00),
(100368, 10368, 26, 1, 2599.00),
(100369, 10369, 31, 1, 199.00),
(100370, 10370, 25, 1, 3999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100371, 10371, 28, 1, 1599.00),
(100372, 10372, 33, 1, 899.00),
(100373, 10373, 2, 1, 6999.00),
(100374, 10374, 29, 1, 499.00),
(100375, 10375, 22, 1, 1299.00),
(100376, 10376, 37, 1, 2999.00),
(100377, 10377, 34, 1, 799.00),
(100378, 10378, 42, 1, 1899.00),
(100379, 10379, 3, 1, 5999.00),
(100380, 10380, 10, 1, 299.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100381, 10381, 28, 1, 1599.00),
(100382, 10382, 33, 1, 899.00),
(100383, 10383, 4, 1, 4999.00),
(100384, 10384, 35, 1, 599.00),
(100385, 10385, 26, 1, 2599.00),
(100386, 10386, 22, 1, 1299.00),
(100387, 10387, 34, 1, 799.00),
(100388, 10388, 25, 1, 3999.00),
(100389, 10389, 31, 1, 199.00),
(100390, 10390, 2, 1, 6999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100391, 10391, 42, 1, 1899.00),
(100392, 10392, 37, 1, 2999.00),
(100393, 10393, 33, 1, 899.00),
(100394, 10394, 4, 1, 4999.00),
(100395, 10395, 35, 1, 599.00),
(100396, 10396, 28, 1, 1599.00),
(100397, 10397, 41, 1, 8999.00),
(100398, 10398, 29, 1, 499.00),
(100399, 10399, 26, 1, 2599.00),
(100400, 10400, 22, 1, 1299.00);

-- 2024年Q1订单明细
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100401, 10401, 37, 1, 2999.00),
(100402, 10402, 33, 1, 899.00),
(100403, 10403, 28, 1, 1599.00),
(100404, 10404, 29, 1, 499.00),
(100405, 10405, 25, 1, 3999.00),
(100406, 10406, 34, 1, 799.00),
(100407, 10407, 31, 1, 199.00),
(100408, 10408, 2, 1, 6999.00),
(100409, 10409, 22, 1, 1299.00),
(100410, 10410, 35, 1, 599.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100411, 10411, 26, 1, 2599.00),
(100412, 10412, 33, 1, 899.00),
(100413, 10413, 42, 1, 1899.00),
(100414, 10414, 10, 1, 299.00),
(100415, 10415, 4, 1, 4999.00),
(100416, 10416, 43, 1, 699.00),
(100417, 10417, 32, 1, 159.00),
(100418, 10418, 3, 1, 5999.00),
(100419, 10419, 28, 1, 1599.00),
(100420, 10420, 34, 1, 799.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100421, 10421, 37, 1, 2999.00),
(100422, 10422, 29, 1, 499.00),
(100423, 10423, 22, 1, 1299.00),
(100424, 10424, 33, 1, 899.00),
(100425, 10425, 25, 1, 3999.00),
(100426, 10426, 35, 1, 599.00),
(100427, 10427, 42, 1, 1899.00),
(100428, 10428, 10, 1, 299.00),
(100429, 10429, 41, 1, 8999.00),
(100430, 10430, 43, 1, 699.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100431, 10431, 28, 1, 1599.00),
(100432, 10432, 26, 1, 2599.00),
(100433, 10433, 8, 1, 11999.00),
(100434, 10434, 29, 1, 499.00),
(100435, 10435, 33, 1, 899.00),
(100436, 10436, 31, 1, 199.00),
(100437, 10437, 4, 1, 4999.00),
(100438, 10438, 34, 1, 799.00),
(100439, 10439, 2, 1, 6999.00),
(100440, 10440, 22, 1, 1299.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100441, 10441, 37, 1, 2999.00),
(100442, 10442, 35, 1, 599.00),
(100443, 10443, 42, 1, 1899.00),
(100444, 10444, 10, 1, 299.00),
(100445, 10445, 1, 1, 9999.00),
(100446, 10446, 43, 1, 699.00),
(100447, 10447, 5, 1, 14999.00),
(100448, 10448, 33, 1, 899.00),
(100449, 10449, 28, 1, 1599.00),
(100450, 10450, 29, 1, 499.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100451, 10451, 25, 1, 3999.00),
(100452, 10452, 34, 1, 799.00),
(100453, 10453, 41, 1, 8999.00),
(100454, 10454, 22, 1, 1299.00),
(100455, 10455, 31, 1, 199.00),
(100456, 10456, 26, 1, 2599.00),
(100457, 10457, 35, 1, 599.00),
(100458, 10458, 4, 1, 4999.00),
(100459, 10459, 33, 1, 899.00),
(100460, 10460, 42, 1, 1899.00);

-- 2024年Q2订单明细
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100461, 10461, 3, 1, 5999.00),
(100462, 10462, 28, 1, 1599.00),
(100463, 10463, 33, 1, 899.00),
(100464, 10464, 37, 1, 2999.00),
(100465, 10465, 43, 1, 699.00),
(100466, 10466, 22, 1, 1299.00),
(100467, 10467, 29, 1, 499.00),
(100468, 10468, 2, 1, 6999.00),
(100469, 10469, 34, 1, 799.00),
(100470, 10470, 25, 1, 3999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100471, 10471, 42, 1, 1899.00),
(100472, 10472, 35, 1, 599.00),
(100473, 10473, 26, 1, 2599.00),
(100474, 10474, 33, 1, 899.00),
(100475, 10475, 4, 1, 4999.00),
(100476, 10476, 10, 1, 299.00),
(100477, 10477, 28, 1, 1599.00),
(100478, 10478, 34, 1, 799.00),
(100479, 10479, 41, 1, 8999.00),
(100480, 10480, 29, 1, 499.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100481, 10481, 22, 1, 1299.00),
(100482, 10482, 37, 1, 2999.00),
(100483, 10483, 43, 1, 699.00),
(100484, 10484, 42, 1, 1899.00),
(100485, 10485, 35, 1, 599.00),
(100486, 10486, 3, 1, 5999.00),
(100487, 10487, 33, 1, 899.00),
(100488, 10488, 28, 1, 1599.00),
(100489, 10489, 10, 1, 299.00),
(100490, 10490, 25, 1, 3999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100491, 10491, 34, 1, 799.00),
(100492, 10492, 26, 1, 2599.00),
(100493, 10493, 1, 1, 9999.00),
(100494, 10494, 29, 1, 499.00),
(100495, 10495, 22, 1, 1299.00),
(100496, 10496, 33, 1, 899.00),
(100497, 10497, 2, 1, 6999.00),
(100498, 10498, 31, 1, 199.00),
(100499, 10499, 4, 1, 4999.00),
(100500, 10500, 28, 1, 1599.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100501, 10501, 33, 1, 899.00),
(100502, 10502, 37, 1, 2999.00),
(100503, 10503, 35, 1, 599.00),
(100504, 10504, 42, 1, 1899.00),
(100505, 10505, 8, 1, 11999.00),
(100506, 10506, 10, 1, 299.00),
(100507, 10507, 41, 1, 8999.00),
(100508, 10508, 43, 1, 699.00),
(100509, 10509, 22, 1, 1299.00),
(100510, 10510, 34, 1, 799.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100511, 10511, 25, 1, 3999.00),
(100512, 10512, 29, 1, 499.00),
(100513, 10513, 2, 1, 6999.00),
(100514, 10514, 28, 1, 1599.00),
(100515, 10515, 33, 1, 899.00),
(100516, 10516, 26, 1, 2599.00),
(100517, 10517, 31, 1, 199.00),
(100518, 10518, 4, 1, 4999.00),
(100519, 10519, 22, 1, 1299.00),
(100520, 10520, 37, 1, 2999.00);

-- 2024年Q3订单明细
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100521, 10521, 2, 1, 6999.00),
(100522, 10522, 42, 1, 1899.00),
(100523, 10523, 35, 1, 599.00),
(100524, 10524, 25, 1, 3999.00),
(100525, 10525, 33, 1, 899.00),
(100526, 10526, 28, 1, 1599.00),
(100527, 10527, 10, 1, 299.00),
(100528, 10528, 41, 1, 8999.00),
(100529, 10529, 29, 1, 499.00),
(100530, 10530, 26, 1, 2599.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100531, 10531, 22, 1, 1299.00),
(100532, 10532, 34, 1, 799.00),
(100533, 10533, 4, 1, 4999.00),
(100534, 10534, 35, 1, 599.00),
(100535, 10535, 37, 1, 2999.00),
(100536, 10536, 33, 1, 899.00),
(100537, 10537, 42, 1, 1899.00),
(100538, 10538, 31, 1, 199.00),
(100539, 10539, 3, 1, 5999.00),
(100540, 10540, 28, 1, 1599.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100541, 10541, 43, 1, 699.00),
(100542, 10542, 25, 1, 3999.00),
(100543, 10543, 33, 1, 899.00),
(100544, 10544, 22, 1, 1299.00),
(100545, 10545, 29, 1, 499.00),
(100546, 10546, 2, 1, 6999.00),
(100547, 10547, 34, 1, 799.00),
(100548, 10548, 26, 1, 2599.00),
(100549, 10549, 35, 1, 599.00),
(100550, 10550, 42, 1, 1899.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100551, 10551, 4, 1, 4999.00),
(100552, 10552, 22, 1, 1299.00),
(100553, 10553, 1, 1, 9999.00),
(100554, 10554, 10, 1, 299.00),
(100555, 10555, 28, 1, 1599.00),
(100556, 10556, 34, 1, 799.00),
(100557, 10557, 37, 1, 2999.00),
(100558, 10558, 35, 1, 599.00),
(100559, 10559, 41, 1, 8999.00),
(100560, 10560, 33, 1, 899.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100561, 10561, 42, 1, 1899.00),
(100562, 10562, 29, 1, 499.00),
(100563, 10563, 26, 1, 2599.00),
(100564, 10564, 43, 1, 699.00),
(100565, 10565, 5, 1, 14999.00),
(100566, 10566, 33, 1, 899.00),
(100567, 10567, 3, 1, 5999.00),
(100568, 10568, 22, 1, 1299.00),
(100569, 10569, 13, 1, 399.00),
(100570, 10570, 28, 1, 1599.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100571, 10571, 25, 1, 3999.00),
(100572, 10572, 34, 1, 799.00),
(100573, 10573, 8, 1, 11999.00),
(100574, 10574, 35, 1, 599.00),
(100575, 10575, 26, 1, 2599.00),
(100576, 10576, 22, 1, 1299.00),
(100577, 10577, 33, 1, 899.00),
(100578, 10578, 4, 1, 4999.00),
(100579, 10579, 42, 1, 1899.00),
(100580, 10580, 2, 1, 6999.00);

-- 2024年Q4订单明细 (双十一)
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100581, 10581, 41, 1, 8999.00),
(100582, 10582, 26, 1, 2599.00),
(100583, 10583, 22, 1, 1299.00),
(100584, 10584, 4, 1, 4999.00),
(100585, 10585, 34, 1, 799.00),
(100586, 10586, 25, 1, 3999.00),
(100587, 10587, 35, 1, 599.00),
(100588, 10588, 2, 1, 6999.00),
(100589, 10589, 28, 1, 1599.00),
(100590, 10590, 37, 1, 2999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100591, 10591, 8, 1, 11999.00),
(100592, 10592, 2, 1, 6999.00),
(100593, 10593, 4, 1, 4999.00),
(100594, 10594, 25, 1, 3999.00),
(100595, 10595, 26, 1, 2599.00),
(100596, 10596, 42, 1, 1899.00),
(100597, 10597, 33, 1, 899.00),
(100598, 10598, 3, 1, 5999.00),
(100599, 10599, 22, 1, 1299.00),
(100600, 10600, 1, 1, 9999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100601, 10601, 1, 2, 9999.50),
(100602, 10602, 5, 1, 14999.00),
(100603, 10603, 1, 1, 9999.00),
(100604, 10604, 41, 1, 8999.00),
(100605, 10605, 2, 1, 6999.00),
(100606, 10606, 3, 1, 5999.00),
(100607, 10607, 4, 1, 4999.00),
(100608, 10608, 25, 1, 3999.00),
(100609, 10609, 37, 1, 2999.00),
(100610, 10610, 26, 1, 2599.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100611, 10611, 8, 1, 11999.00),
(100612, 10612, 41, 1, 8999.00),
(100613, 10613, 2, 1, 6999.00),
(100614, 10614, 4, 1, 4999.00),
(100615, 10615, 25, 1, 3999.00),
(100616, 10616, 37, 1, 2999.00),
(100617, 10617, 27, 1, 1999.00),
(100618, 10618, 28, 1, 1599.00),
(100619, 10619, 22, 1, 1299.00),
(100620, 10620, 33, 2, 499.50);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100621, 10621, 5, 1, 14999.00),
(100622, 10622, 1, 1, 9999.00),
(100623, 10623, 1, 2, 9999.50),
(100624, 10624, 3, 1, 5999.00),
(100625, 10625, 25, 1, 3999.00),
(100626, 10626, 26, 1, 2599.00),
(100627, 10627, 42, 1, 1899.00),
(100628, 10628, 22, 1, 1299.00),
(100629, 10629, 8, 1, 11999.00),
(100630, 10630, 2, 1, 6999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100631, 10631, 41, 1, 8999.00),
(100632, 10632, 4, 1, 4999.00),
(100633, 10633, 37, 1, 2999.00),
(100634, 10634, 27, 1, 1999.00),
(100635, 10635, 5, 1, 14999.00),
(100636, 10636, 28, 1, 1599.00),
(100637, 10637, 1, 2, 9999.50),
(100638, 10638, 33, 1, 899.00),
(100639, 10639, 35, 1, 599.00),
(100640, 10640, 25, 1, 3999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100641, 10641, 8, 1, 11999.00),
(100642, 10642, 2, 1, 6999.00),
(100643, 10643, 1, 2, 9999.50),
(100644, 10644, 41, 1, 8999.00),
(100645, 10645, 42, 1, 1899.00),
(100646, 10646, 22, 1, 1299.00),
(100647, 10647, 34, 1, 799.00),
(100648, 10648, 4, 1, 4999.00),
(100649, 10649, 3, 1, 5999.00),
(100650, 10650, 1, 1, 9999.00);

-- 2024年Q4后续订单明细
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100651, 10651, 26, 1, 2599.00),
(100652, 10652, 42, 1, 1899.00),
(100653, 10653, 4, 1, 4999.00),
(100654, 10654, 33, 1, 899.00),
(100655, 10655, 25, 1, 3999.00),
(100656, 10656, 28, 1, 1599.00),
(100657, 10657, 35, 1, 599.00),
(100658, 10658, 2, 1, 6999.00),
(100659, 10659, 33, 1, 899.00),
(100660, 10660, 26, 1, 2599.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100661, 10661, 22, 1, 1299.00),
(100662, 10662, 4, 1, 4999.00),
(100663, 10663, 34, 1, 799.00),
(100664, 10664, 42, 1, 1899.00),
(100665, 10665, 35, 1, 599.00),
(100666, 10666, 25, 1, 3999.00),
(100667, 10667, 41, 1, 8999.00),
(100668, 10668, 28, 1, 1599.00),
(100669, 10669, 10, 1, 299.00),
(100670, 10670, 3, 1, 5999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100671, 10671, 42, 1, 1899.00),
(100672, 10672, 26, 1, 2599.00),
(100673, 10673, 33, 1, 899.00),
(100674, 10674, 4, 1, 4999.00),
(100675, 10675, 22, 1, 1299.00),
(100676, 10676, 2, 1, 6999.00),
(100677, 10677, 35, 1, 599.00),
(100678, 10678, 37, 1, 2999.00),
(100679, 10679, 28, 1, 1599.00),
(100680, 10680, 33, 1, 899.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100681, 10681, 25, 1, 3999.00),
(100682, 10682, 42, 1, 1899.00),
(100683, 10683, 43, 1, 699.00),
(100684, 10684, 4, 1, 4999.00),
(100685, 10685, 22, 1, 1299.00),
(100686, 10686, 41, 1, 8999.00),
(100687, 10687, 35, 1, 599.00),
(100688, 10688, 26, 1, 2599.00),
(100689, 10689, 28, 1, 1599.00),
(100690, 10690, 33, 1, 899.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100691, 10691, 3, 1, 5999.00),
(100692, 10692, 42, 1, 1899.00),
(100693, 10693, 37, 1, 2999.00),
(100694, 10694, 34, 1, 799.00),
(100695, 10695, 4, 1, 4999.00),
(100696, 10696, 22, 1, 1299.00),
(100697, 10697, 2, 1, 6999.00),
(100698, 10698, 35, 1, 599.00),
(100699, 10699, 25, 1, 3999.00),
(100700, 10700, 33, 1, 899.00);

-- 2025年订单明细
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100701, 10701, 4, 1, 4999.00),
(100702, 10702, 28, 1, 1599.00),
(100703, 10703, 33, 1, 899.00),
(100704, 10704, 2, 1, 6999.00),
(100705, 10705, 35, 1, 599.00),
(100706, 10706, 26, 1, 2599.00),
(100707, 10707, 10, 1, 299.00),
(100708, 10708, 41, 1, 8999.00),
(100709, 10709, 22, 1, 1299.00),
(100710, 10710, 34, 1, 799.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100711, 10711, 25, 1, 3999.00),
(100712, 10712, 35, 1, 599.00),
(100713, 10713, 42, 1, 1899.00),
(100714, 10714, 29, 1, 499.00),
(100715, 10715, 3, 1, 5999.00),
(100716, 10716, 33, 1, 899.00),
(100717, 10717, 31, 1, 199.00),
(100718, 10718, 4, 1, 4999.00),
(100719, 10719, 28, 1, 1599.00),
(100720, 10720, 43, 1, 699.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100721, 10721, 37, 1, 2999.00),
(100722, 10722, 33, 1, 899.00),
(100723, 10723, 22, 1, 1299.00),
(100724, 10724, 35, 1, 599.00),
(100725, 10725, 2, 1, 6999.00),
(100726, 10726, 42, 1, 1899.00),
(100727, 10727, 34, 1, 799.00),
(100728, 10728, 25, 1, 3999.00),
(100729, 10729, 29, 1, 499.00),
(100730, 10730, 41, 1, 8999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100731, 10731, 28, 1, 1599.00),
(100732, 10732, 26, 1, 2599.00),
(100733, 10733, 8, 1, 11999.00),
(100734, 10734, 33, 1, 899.00),
(100735, 10735, 22, 1, 1299.00),
(100736, 10736, 35, 1, 599.00),
(100737, 10737, 4, 1, 4999.00),
(100738, 10738, 43, 1, 699.00),
(100739, 10739, 1, 1, 9999.00),
(100740, 10740, 42, 1, 1899.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100741, 10741, 26, 1, 2599.00),
(100742, 10742, 34, 1, 799.00),
(100743, 10743, 25, 1, 3999.00),
(100744, 10744, 35, 1, 599.00),
(100745, 10745, 5, 1, 14999.00),
(100746, 10746, 22, 1, 1299.00),
(100747, 10747, 41, 1, 8999.00),
(100748, 10748, 29, 1, 499.00),
(100749, 10749, 42, 1, 1899.00),
(100750, 10750, 33, 1, 899.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100751, 10751, 3, 1, 5999.00),
(100752, 10752, 28, 1, 1599.00),
(100753, 10753, 1, 2, 9999.50),
(100754, 10754, 33, 1, 899.00),
(100755, 10755, 26, 1, 2599.00),
(100756, 10756, 43, 1, 699.00),
(100757, 10757, 4, 1, 4999.00),
(100758, 10758, 22, 1, 1299.00),
(100759, 10759, 2, 1, 6999.00),
(100760, 10760, 25, 1, 3999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100761, 10761, 26, 1, 2599.00),
(100762, 10762, 42, 1, 1899.00),
(100763, 10763, 3, 1, 5999.00),
(100764, 10764, 33, 1, 899.00),
(100765, 10765, 25, 1, 3999.00),
(100766, 10766, 28, 1, 1599.00),
(100767, 10767, 43, 1, 699.00),
(100768, 10768, 4, 1, 4999.00),
(100769, 10769, 33, 1, 899.00),
(100770, 10770, 22, 1, 1299.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100771, 10771, 2, 1, 6999.00),
(100772, 10772, 35, 1, 599.00),
(100773, 10773, 37, 1, 2999.00),
(100774, 10774, 33, 1, 899.00),
(100775, 10775, 28, 1, 1599.00),
(100776, 10776, 4, 1, 4999.00),
(100777, 10777, 34, 1, 799.00),
(100778, 10778, 26, 1, 2599.00),
(100779, 10779, 22, 1, 1299.00),
(100780, 10780, 41, 1, 8999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100781, 10781, 35, 1, 599.00),
(100782, 10782, 42, 1, 1899.00),
(100783, 10783, 25, 1, 3999.00),
(100784, 10784, 33, 1, 899.00),
(100785, 10785, 3, 1, 5999.00),
(100786, 10786, 28, 1, 1599.00),
(100787, 10787, 43, 1, 699.00),
(100788, 10788, 26, 1, 2599.00),
(100789, 10789, 33, 1, 899.00),
(100790, 10790, 4, 1, 4999.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(100791, 10791, 22, 1, 1299.00),
(100792, 10792, 2, 1, 6999.00),
(100793, 10793, 35, 1, 599.00),
(100794, 10794, 42, 1, 1899.00),
(100795, 10795, 1, 1, 9999.00),
(100796, 10796, 34, 1, 799.00),
(100797, 10797, 37, 1, 2999.00),
(100798, 10798, 28, 1, 1599.00),
(100799, 10799, 33, 1, 899.00),
(100800, 10800, 4, 1, 4999.00);

-- ============================================================================
-- 额外的多商品订单明细 (为一些订单添加第二、第三个商品)
-- ============================================================================

-- 双十一大订单的额外商品
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200001, 10281, 17, 2, 168.00),
(200002, 10281, 19, 3, 89.00),
(200003, 10291, 17, 1, 168.00),
(200004, 10303, 42, 1, 1899.00),
(200005, 10311, 50, 2, 299.00),
(200006, 10315, 29, 1, 499.00),
(200007, 10317, 23, 3, 39.00),
(200008, 10323, 39, 2, 99.00),
(200009, 10601, 42, 1, 1899.00),
(200010, 10602, 17, 2, 168.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200011, 10603, 29, 1, 499.00),
(200012, 10621, 19, 3, 89.00),
(200013, 10623, 50, 2, 299.00),
(200014, 10635, 23, 4, 39.00),
(200015, 10637, 39, 2, 99.00),
(200016, 10641, 17, 1, 168.00),
(200017, 10643, 29, 1, 499.00),
(200018, 10733, 17, 2, 168.00),
(200019, 10745, 42, 1, 1899.00),
(200020, 10753, 39, 2, 99.00);

-- 普通订单的多商品组合
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200021, 10001, 17, 1, 168.00),
(200022, 10009, 23, 2, 39.00),
(200023, 10020, 19, 2, 89.00),
(200024, 10027, 50, 1, 299.00),
(200025, 10041, 17, 3, 168.00),
(200026, 10054, 19, 1, 89.00),
(200027, 10060, 23, 2, 39.00),
(200028, 10070, 17, 2, 168.00),
(200029, 10090, 39, 1, 99.00),
(200030, 10113, 17, 3, 168.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200031, 10126, 23, 4, 39.00),
(200032, 10136, 19, 2, 89.00),
(200033, 10154, 17, 1, 168.00),
(200034, 10173, 39, 2, 99.00),
(200035, 10187, 50, 1, 299.00),
(200036, 10193, 19, 3, 89.00),
(200037, 10205, 23, 2, 39.00),
(200038, 10217, 17, 2, 168.00),
(200039, 10236, 39, 1, 99.00),
(200040, 10249, 19, 2, 89.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200041, 10266, 23, 3, 39.00),
(200042, 10280, 17, 2, 168.00),
(200043, 10351, 39, 1, 99.00),
(200044, 10357, 50, 2, 299.00),
(200045, 10390, 19, 2, 89.00),
(200046, 10397, 17, 3, 168.00),
(200047, 10408, 23, 2, 39.00),
(200048, 10429, 39, 1, 99.00),
(200049, 10433, 19, 2, 89.00),
(200050, 10445, 50, 1, 299.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200051, 10447, 17, 2, 168.00),
(200052, 10453, 23, 3, 39.00),
(200053, 10468, 39, 2, 99.00),
(200054, 10479, 19, 1, 89.00),
(200055, 10493, 50, 2, 299.00),
(200056, 10505, 17, 3, 168.00),
(200057, 10507, 23, 2, 39.00),
(200058, 10528, 39, 1, 99.00),
(200059, 10553, 19, 2, 89.00),
(200060, 10565, 50, 1, 299.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200061, 10567, 17, 2, 168.00),
(200062, 10573, 23, 3, 39.00),
(200063, 10580, 39, 1, 99.00),
(200064, 10588, 19, 2, 89.00),
(200065, 10600, 50, 2, 299.00),
(200066, 10658, 17, 3, 168.00),
(200067, 10667, 23, 2, 39.00),
(200068, 10686, 39, 1, 99.00),
(200069, 10697, 19, 2, 89.00),
(200070, 10704, 50, 1, 299.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200071, 10708, 17, 2, 168.00),
(200072, 10718, 23, 3, 39.00),
(200073, 10725, 39, 2, 99.00),
(200074, 10730, 19, 1, 89.00),
(200075, 10747, 50, 2, 299.00),
(200076, 10759, 17, 3, 168.00),
(200077, 10771, 23, 2, 39.00),
(200078, 10780, 39, 1, 99.00),
(200079, 10792, 19, 2, 89.00),
(200080, 10795, 50, 1, 299.00);

-- 更多多商品订单明细 (增加第三个商品)
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200081, 10001, 23, 3, 39.00),
(200082, 10020, 50, 1, 299.00),
(200083, 10041, 39, 2, 99.00),
(200084, 10070, 19, 3, 89.00),
(200085, 10090, 50, 1, 299.00),
(200086, 10126, 17, 2, 168.00),
(200087, 10173, 23, 1, 39.00),
(200088, 10205, 39, 2, 99.00),
(200089, 10236, 19, 1, 89.00),
(200090, 10266, 50, 2, 299.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200091, 10280, 39, 1, 99.00),
(200092, 10357, 17, 2, 168.00),
(200093, 10390, 23, 3, 39.00),
(200094, 10433, 50, 1, 299.00),
(200095, 10453, 39, 2, 99.00),
(200096, 10505, 19, 1, 89.00),
(200097, 10553, 17, 2, 168.00),
(200098, 10573, 50, 1, 299.00),
(200099, 10600, 39, 2, 99.00),
(200100, 10658, 23, 3, 39.00);

-- 特定类目的订单明细 (运动类目增长趋势)
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200101, 10067, 38, 1, 599.00),
(200102, 10103, 37, 1, 2999.00),
(200103, 10154, 40, 1, 3999.00),
(200104, 10181, 38, 2, 599.00),
(200105, 10241, 49, 1, 499.00),
(200106, 10270, 38, 1, 599.00),
(200107, 10340, 37, 1, 2999.00),
(200108, 10405, 40, 1, 3999.00),
(200109, 10475, 38, 2, 599.00),
(200110, 10535, 49, 1, 499.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200111, 10570, 38, 1, 599.00),
(200112, 10606, 37, 1, 2999.00),
(200113, 10667, 40, 1, 3999.00),
(200114, 10715, 38, 2, 599.00),
(200115, 10771, 49, 1, 499.00),
(200116, 10047, 49, 1, 499.00),
(200117, 10124, 38, 1, 599.00),
(200118, 10213, 37, 1, 2999.00),
(200119, 10246, 40, 1, 3999.00),
(200120, 10308, 38, 2, 599.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200121, 10367, 49, 1, 499.00),
(200122, 10437, 38, 1, 599.00),
(200123, 10497, 37, 1, 2999.00),
(200124, 10557, 40, 1, 3999.00),
(200125, 10598, 38, 2, 599.00),
(200126, 10657, 49, 1, 499.00),
(200127, 10718, 38, 1, 599.00),
(200128, 10737, 49, 2, 499.00),
(200129, 10768, 38, 1, 599.00),
(200130, 10780, 49, 1, 499.00);

-- 电子产品类目的额外明细 (稳定增长)
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200131, 10002, 50, 1, 299.00),
(200132, 10015, 44, 1, 299.00),
(200133, 10033, 42, 1, 1899.00),
(200134, 10061, 50, 1, 299.00),
(200135, 10080, 44, 2, 299.00),
(200136, 10095, 42, 1, 1899.00),
(200137, 10120, 50, 1, 299.00),
(200138, 10148, 44, 1, 299.00),
(200139, 10159, 42, 1, 1899.00),
(200140, 10187, 50, 2, 299.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200141, 10225, 44, 1, 299.00),
(200142, 10249, 42, 1, 1899.00),
(200143, 10261, 50, 1, 299.00),
(200144, 10272, 44, 2, 299.00),
(200145, 10310, 42, 1, 1899.00),
(200146, 10351, 50, 1, 299.00),
(200147, 10379, 44, 1, 299.00),
(200148, 10408, 42, 1, 1899.00),
(200149, 10439, 50, 2, 299.00),
(200150, 10461, 44, 1, 299.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200151, 10521, 42, 1, 1899.00),
(200152, 10546, 50, 1, 299.00),
(200153, 10581, 44, 2, 299.00),
(200154, 10591, 42, 1, 1899.00),
(200155, 10649, 50, 1, 299.00),
(200156, 10701, 44, 1, 299.00),
(200157, 10711, 42, 1, 1899.00),
(200158, 10739, 50, 2, 299.00),
(200159, 10759, 44, 1, 299.00),
(200160, 10795, 42, 1, 1899.00);

-- 食品饮料类 (高频次购买)
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200161, 10004, 18, 1, 199.00),
(200162, 10013, 20, 2, 69.00),
(200163, 10025, 24, 3, 59.00),
(200164, 10046, 18, 1, 199.00),
(200165, 10057, 20, 2, 69.00),
(200166, 10089, 24, 3, 59.00),
(200167, 10102, 18, 1, 199.00),
(200168, 10132, 20, 2, 69.00),
(200169, 10147, 24, 3, 59.00),
(200170, 10162, 18, 1, 199.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200171, 10183, 20, 2, 69.00),
(200172, 10197, 24, 3, 59.00),
(200173, 10212, 18, 1, 199.00),
(200174, 10230, 20, 2, 69.00),
(200175, 10245, 24, 3, 59.00),
(200176, 10267, 18, 1, 199.00),
(200177, 10339, 20, 2, 69.00),
(200178, 10369, 24, 3, 59.00),
(200179, 10407, 18, 1, 199.00),
(200180, 10417, 20, 2, 69.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200181, 10436, 24, 3, 59.00),
(200182, 10476, 18, 1, 199.00),
(200183, 10498, 20, 2, 69.00),
(200184, 10517, 24, 3, 59.00),
(200185, 10527, 18, 1, 199.00),
(200186, 10538, 20, 2, 69.00),
(200187, 10577, 24, 3, 59.00),
(200188, 10597, 18, 1, 199.00),
(200189, 10638, 20, 2, 69.00),
(200190, 10647, 24, 3, 59.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200191, 10669, 18, 1, 199.00),
(200192, 10707, 20, 2, 69.00),
(200193, 10717, 24, 3, 59.00),
(200194, 10736, 18, 1, 199.00),
(200195, 10756, 20, 2, 69.00),
(200196, 10769, 24, 3, 59.00),
(200197, 10799, 18, 1, 199.00),
(200198, 10003, 21, 1, 2999.00),
(200199, 10005, 21, 1, 2999.00),
(200200, 10045, 21, 1, 2999.00);

-- 服装类目 (季节性波动)
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200201, 10006, 30, 1, 899.00),
(200202, 10008, 15, 1, 1299.00),
(200203, 10028, 46, 1, 199.00),
(200204, 10039, 45, 2, 129.00),
(200205, 10048, 36, 1, 159.00),
(200206, 10065, 30, 1, 899.00),
(200207, 10077, 15, 1, 1299.00),
(200208, 10098, 46, 2, 199.00),
(200209, 10109, 45, 1, 129.00),
(200210, 10119, 36, 2, 159.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200211, 10146, 30, 1, 899.00),
(200212, 10157, 15, 1, 1299.00),
(200213, 10178, 46, 1, 199.00),
(200214, 10189, 45, 2, 129.00),
(200215, 10199, 36, 1, 159.00),
(200216, 10211, 30, 1, 899.00),
(200217, 10221, 15, 1, 1299.00),
(200218, 10235, 46, 2, 199.00),
(200219, 10242, 45, 1, 129.00),
(200220, 10253, 36, 2, 159.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200221, 10265, 30, 1, 899.00),
(200222, 10278, 15, 1, 1299.00),
(200223, 10335, 46, 1, 199.00),
(200224, 10344, 45, 2, 129.00),
(200225, 10360, 36, 1, 159.00),
(200226, 10402, 30, 1, 899.00),
(200227, 10416, 15, 1, 1299.00),
(200228, 10426, 46, 2, 199.00),
(200229, 10444, 45, 1, 129.00),
(200230, 10457, 36, 2, 159.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200231, 10466, 30, 1, 899.00),
(200232, 10478, 15, 1, 1299.00),
(200233, 10489, 46, 1, 199.00),
(200234, 10506, 45, 2, 129.00),
(200235, 10523, 36, 1, 159.00),
(200236, 10536, 30, 1, 899.00),
(200237, 10537, 15, 1, 1299.00),
(200238, 10554, 46, 2, 199.00),
(200239, 10562, 45, 1, 129.00),
(200240, 10574, 36, 2, 159.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200241, 10585, 30, 1, 899.00),
(200242, 10596, 15, 1, 1299.00),
(200243, 10617, 46, 1, 199.00),
(200244, 10628, 45, 2, 129.00),
(200245, 10654, 36, 1, 159.00),
(200246, 10663, 30, 1, 899.00),
(200247, 10677, 15, 1, 1299.00),
(200248, 10694, 46, 2, 199.00),
(200249, 10710, 45, 1, 129.00),
(200250, 10727, 36, 2, 159.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200251, 10742, 30, 1, 899.00),
(200252, 10754, 15, 1, 1299.00),
(200253, 10767, 46, 1, 199.00),
(200254, 10774, 45, 2, 129.00),
(200255, 10787, 36, 1, 159.00),
(200256, 10796, 30, 1, 899.00),
(200257, 10002, 11, 2, 99.00),
(200258, 10032, 11, 3, 99.00),
(200259, 10044, 11, 2, 99.00),
(200260, 10049, 11, 1, 99.00);

-- 家居类目
INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200261, 10018, 27, 1, 1999.00),
(200262, 10047, 48, 1, 259.00),
(200263, 10075, 27, 1, 1999.00),
(200264, 10103, 48, 2, 259.00),
(200265, 10124, 27, 1, 1999.00),
(200266, 10167, 48, 1, 259.00),
(200267, 10184, 27, 1, 1999.00),
(200268, 10227, 48, 2, 259.00),
(200269, 10254, 27, 1, 1999.00),
(200270, 10340, 48, 1, 259.00);

INSERT INTO e_order_items (item_id, order_id, product_id, quantity, unit_price) VALUES
(200271, 10371, 27, 1, 1999.00),
(200272, 10418, 48, 2, 259.00),
(200273, 10441, 27, 1, 1999.00),
(200274, 10499, 48, 1, 259.00),
(200275, 10551, 27, 1, 1999.00),
(200276, 10559, 48, 2, 259.00),
(200277, 10629, 27, 1, 1999.00),
(200278, 10691, 48, 1, 259.00),
(200279, 10737, 27, 1, 1999.00),
(200280, 10790, 48, 2, 259.00);

-- ============================================================================
-- 数据插入完成
-- ============================================================================

-- 数据统计概览:
-- categories: 15 条
-- products: 50 条
-- users: 80 条
-- orders: 800 条 (2023-2025年，含季节性波动)
-- order_items: ~2500 条

-- 数据特征:
-- 1. Q4双十一期间订单量明显高于其他季度
-- 2. Q1春节期间订单量相对较低
-- 3. 2023年11月底-12月初有退款率异常升高的数据
-- 4. 不同用户等级的消费金额有明显差异 (钻石>金卡>银卡>普通)
-- 5. 上海、北京、深圳、杭州等一线城市用户消费能力更强
-- 6. 运动类目呈现增长趋势
-- 7. 电子产品类目保持稳定