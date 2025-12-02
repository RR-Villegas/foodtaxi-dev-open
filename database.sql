/*
SQLyog Ultimate v10.00 Beta1
MySQL - 5.5.5-10.4.32-MariaDB : Database - foodtaxi_omega
*********************************************************************
*/


/*!40101 SET NAMES utf8 */;

/*!40101 SET SQL_MODE=''*/;

/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
CREATE DATABASE /*!32312 IF NOT EXISTS*/`foodtaxi_omega` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci */;

USE `foodtaxi_omega`;

/*Table structure for table `account` */

DROP TABLE IF EXISTS `account`;

CREATE TABLE `account` (
  `account_id` int(11) NOT NULL AUTO_INCREMENT,
  `firstname` varchar(100) NOT NULL,
  `surname` varchar(100) NOT NULL,
  `email` varchar(255) NOT NULL,
  `home_address` varchar(255) DEFAULT NULL,
  `street_address` varchar(255) DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `province` varchar(100) DEFAULT NULL,
  `region` varchar(100) DEFAULT NULL,
  `zip_code` varchar(10) DEFAULT NULL,
  `phone_number` varchar(20) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `account_type` enum('Buyer','Seller','Rider') NOT NULL DEFAULT 'Buyer',
  `is_email_verified` tinyint(1) DEFAULT 0,
  `is_verified` tinyint(1) DEFAULT 0,
  `date_created` datetime DEFAULT current_timestamp(),
  `date_verified` datetime DEFAULT NULL,
  PRIMARY KEY (`account_id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `phone_number` (`phone_number`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `account` */

insert  into `account`(`account_id`,`firstname`,`surname`,`email`,`home_address`,`street_address`,`city`,`province`,`region`,`zip_code`,`phone_number`,`password_hash`,`account_type`,`is_email_verified`,`is_verified`,`date_created`,`date_verified`) values (1,'Fishbaitss','F','fish@example.com','198','3124','043407000','043400000','040000000','4013','09690272140','scrypt:32768:8:1$8CMAfFCwSp3HkOqz$b059e4216cc0510b760fc26c44f17a8acb5a4a4bb502345c9e12bfbbd8f7680fb54ffe557c7387497e0c7c35a262479cd049ddfe8db9dfae5202dbc7b0193bc9','Buyer',1,1,'2025-12-03 01:27:16',NULL),(2,'Jaymark','Virina','Jaymark@gmail.com','0112-1234','223123123','043425000','043400000','040000000','1234','09090909091','scrypt:32768:8:1$oo26kDOBW8rlZvpf$f6b6d90289354447f8e3b85e7ab703094685a6742e189d289ba3b9f947cef638802363961486ffb22cbabf97433f79190ee19d80171b1f91b451c0654a2ea293','Buyer',1,1,'2025-12-03 01:37:36',NULL),(3,'broom','clad','broom@gmail.com','0112-1234','asdasdadas','043405000','043400000','040000000','1233','09090909092','scrypt:32768:8:1$ON4dgNQYbqgJMpIB$bc4dcce4c58eedaf3958d69649382f2332aa8d2263c6f26c757b4e56592d464478e9bca65b915be72239dc0921971bb1b03acc4fba9e91828331120f4cb2e50f','Seller',1,1,'2025-12-03 01:42:13',NULL),(4,'sugoma','sugoma','seller@example.com','123','234312ssa','043408000','043400000','040000000','4021','12356789432','scrypt:32768:8:1$dnQD2nf2QBFvH4kX$736fc455f08423759b1161addb5c07f8da598ad32f988bcb78d366da2403274be0f331a15a32762d687056bcdbbe6a5452dda8a363acd029342f9b3b5ed3a1f7','Seller',1,1,'2025-12-03 01:50:08',NULL),(5,'andrew','castillo','andrew@gmail.com','dada','asdasd','043426000','043400000','040000000','1600','123124','scrypt:32768:8:1$2PkeCAoQLOKjEJY1$ae0dd9d248ae7c6b4c98e093dfb879d203f6f49d38052bae71efc25f29caafa8bac83bec4d982836cda39ef9a348ca4c46470600b897c614091a7591617d92c9','Buyer',1,1,'2025-12-03 01:50:24',NULL),(6,'Andrew','Castillo','Drew@gmail.com','0112-1234','asdasdadas','043426000','043400000','040000000','1782','12345678912','scrypt:32768:8:1$ivAlNBku7AjtzkoV$d272d928ac352cc2e95f822025943003a33896b948e1474e71e7b43cb356a18e3f51f9f19f42fed0705c89d41be25cdfe6537e5fee2a1d35f9b321fe766e1058','Seller',1,1,'2025-12-03 06:01:11',NULL),(7,'Nath','Ramos','Nath@gmail.com','0112-1234','asdasdadas','043426000','043400000','040000000','5643','1345647285','scrypt:32768:8:1$eZuDZWISXGXLMmYp$6ee603ed892ce9cb77c5aa5ccc33a59572305ca218fd403d8124c25dcaca0cc860406e8986ee19fb5b649af37754d732f28657e0d27e7c2e1023d0357f8b9cea','Seller',1,1,'2025-12-03 06:12:09',NULL);

/*Table structure for table `buyer_verification` */

DROP TABLE IF EXISTS `buyer_verification`;

CREATE TABLE `buyer_verification` (
  `verification_id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) NOT NULL,
  `otp_code` varchar(6) DEFAULT NULL,
  `otp_expiry` datetime DEFAULT NULL,
  `otp_verified` tinyint(1) DEFAULT 0,
  `otp_method` enum('Email','SMS') DEFAULT 'Email',
  `status` enum('Pending OTP','Verified','Rejected') NOT NULL DEFAULT 'Pending OTP',
  `submission_date` datetime DEFAULT current_timestamp(),
  `verification_date` datetime DEFAULT NULL,
  `review_notes` text DEFAULT NULL,
  PRIMARY KEY (`verification_id`),
  UNIQUE KEY `account_id` (`account_id`),
  CONSTRAINT `buyer_verification_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `buyer_verification` */

/*Table structure for table `cart` */

DROP TABLE IF EXISTS `cart`;

CREATE TABLE `cart` (
  `cart_id` int(11) NOT NULL AUTO_INCREMENT,
  `buyer_account_id` int(11) NOT NULL,
  `date_created` datetime DEFAULT current_timestamp(),
  `last_updated` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `status` enum('Active','Converted','Abandoned') NOT NULL DEFAULT 'Active',
  PRIMARY KEY (`cart_id`),
  UNIQUE KEY `buyer_account_id` (`buyer_account_id`),
  CONSTRAINT `cart_ibfk_1` FOREIGN KEY (`buyer_account_id`) REFERENCES `account` (`account_id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `cart` */

insert  into `cart`(`cart_id`,`buyer_account_id`,`date_created`,`last_updated`,`status`) values (1,1,'2025-12-03 04:18:51','2025-12-03 04:18:51','Active'),(2,2,'2025-12-03 06:30:05','2025-12-03 06:30:05','Active');

/*Table structure for table `cart_item` */

DROP TABLE IF EXISTS `cart_item`;

CREATE TABLE `cart_item` (
  `cart_item_id` int(11) NOT NULL AUTO_INCREMENT,
  `cart_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `quantity` int(11) NOT NULL CHECK (`quantity` >= 1),
  `added_date` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`cart_item_id`),
  UNIQUE KEY `unique_cart_product` (`cart_id`,`product_id`),
  KEY `cart_item_ibfk_2` (`product_id`),
  CONSTRAINT `cart_item_ibfk_1` FOREIGN KEY (`cart_id`) REFERENCES `cart` (`cart_id`),
  CONSTRAINT `cart_item_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `product` (`product_id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `cart_item` */

insert  into `cart_item`(`cart_item_id`,`cart_id`,`product_id`,`quantity`,`added_date`) values (12,1,93,1,'2025-12-03 06:50:02'),(13,2,96,1,'2025-12-03 07:12:04'),(14,2,95,1,'2025-12-03 07:12:11');

/*Table structure for table `order_items` */

DROP TABLE IF EXISTS `order_items`;

CREATE TABLE `order_items` (
  `order_item_id` int(11) NOT NULL AUTO_INCREMENT,
  `order_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `quantity` int(11) NOT NULL,
  `unit_price_at_sale` decimal(10,2) NOT NULL,
  `subtotal` decimal(10,2) NOT NULL,
  PRIMARY KEY (`order_item_id`),
  UNIQUE KEY `order_id` (`order_id`,`product_id`),
  KEY `product_id` (`product_id`),
  CONSTRAINT `order_items_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`),
  CONSTRAINT `order_items_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `product` (`product_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `order_items` */

/*Table structure for table `orders` */

DROP TABLE IF EXISTS `orders`;

CREATE TABLE `orders` (
  `order_id` int(11) NOT NULL AUTO_INCREMENT,
  `buyer_account_id` int(11) NOT NULL,
  `cart_id` int(11) DEFAULT NULL,
  `order_date` datetime DEFAULT current_timestamp(),
  `payment_status` enum('Pending','Paid','Failed','Refunded') NOT NULL DEFAULT 'Pending',
  `status` enum('Processing','Ready for Pickup','In Transit','Delivered','Cancelled') NOT NULL DEFAULT 'Processing',
  `total_amount` decimal(10,2) NOT NULL,
  `payment_method` enum('Cash on Delivery','GCash','Card') NOT NULL DEFAULT 'Cash on Delivery',
  `shipping_fee` decimal(10,2) DEFAULT 0.00,
  `shipping_address_line` varchar(255) DEFAULT NULL,
  `shipping_city` varchar(100) DEFAULT NULL,
  `rider_account_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`order_id`),
  UNIQUE KEY `fk_cart_order` (`cart_id`),
  KEY `buyer_account_id` (`buyer_account_id`),
  KEY `rider_account_id` (`rider_account_id`),
  CONSTRAINT `orders_ibfk_1` FOREIGN KEY (`buyer_account_id`) REFERENCES `account` (`account_id`),
  CONSTRAINT `orders_ibfk_2` FOREIGN KEY (`rider_account_id`) REFERENCES `account` (`account_id`),
  CONSTRAINT `orders_ibfk_3` FOREIGN KEY (`cart_id`) REFERENCES `cart` (`cart_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `orders` */

/*Table structure for table `product` */

DROP TABLE IF EXISTS `product`;

CREATE TABLE `product` (
  `product_id` int(11) NOT NULL AUTO_INCREMENT,
  `seller_account_id` int(11) NOT NULL,
  `product_slug` varchar(150) NOT NULL,
  `category` enum('Baking Supplies & Ingredients','Coffee, Tea & Beverages','Snacks & Candy','Specialty Foods & International Cuisine','Organic and Health Foods','Meal Kits & Prepped Foods') NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `price` decimal(10,2) NOT NULL,
  `stock_quantity` int(11) NOT NULL DEFAULT 0,
  `sku` varchar(50) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `main_image_url` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`product_id`),
  UNIQUE KEY `product_slug` (`product_slug`),
  UNIQUE KEY `product_slug_2` (`product_slug`),
  UNIQUE KEY `sku` (`sku`),
  KEY `seller_account_id` (`seller_account_id`),
  CONSTRAINT `product_ibfk_1` FOREIGN KEY (`seller_account_id`) REFERENCES `account` (`account_id`)
) ENGINE=InnoDB AUTO_INCREMENT=98 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `product` */

insert  into `product`(`product_id`,`seller_account_id`,`product_slug`,`category`,`name`,`description`,`price`,`stock_quantity`,`sku`,`is_active`,`main_image_url`) values (1,4,'tung-tung-tung-sahur','Specialty Foods & International Cuisine','TUNG TUNG TUNG SAHUR','676767','6767.00',6767,NULL,1,'TUNG_TUNG_TUNG_SAHUR_20251203023212.png'),(2,3,'micah-coffee-blend','Coffee, Tea & Beverages','Micah','adgsgsdfaf','20.00',45,NULL,1,'Micah_20251203025854.jpg'),(7,4,'asfdas','Baking Supplies & Ingredients','asfdas','wrewrewf','245.00',255,NULL,1,'asfdas_20251203050353.jpg'),(8,3,'all-purpose-flour','Baking Supplies & Ingredients','All Purpose Flour','This is a High Quality Flour','500.00',100,NULL,1,'All_Purpose_Flour_20251203053239.jpg'),(73,3,'organic-white-all-purpose-flour','Baking Supplies & Ingredients','Organic White All Purpose Flour','All Purpose Flour :)))))','200.00',50,NULL,1,'Organic_White_All_Purpose_Flour_20251203053539.jpg'),(74,3,'baron-all-purpose-flour','Baking Supplies & Ingredients','Baron All Purpose Flour','A High Quality Flour (We are not responsible for any issues that customers may experience.)','600.00',69,NULL,1,'Baron_All_Purpose_Flour_20251203054009.jpg'),(75,3,'pilmico-all-purpose-flour','Baking Supplies & Ingredients','Pilmico All Purpose Flour','A versatile, finely milled flour made from a blend of hard and soft wheat. Perfect for a wide range of baking and cooking needs, including bread, cakes, cookies, pancakes, and sauces. It provides a balanced texture and structure, making it a staple in most kitchens.','799.00',500,NULL,1,'Pilmico_All_Purpose_Flour_20251203054253.png'),(76,3,'swan-all-purpose-flour','Baking Supplies & Ingredients','SWAN All Purpose Flour','A premium all-purpose flour known for its consistent quality and fine texture. Ideal for baking breads, cakes, pastries, and everyday cooking, Swan Flour delivers reliable results and a soft, light texture in all your recipes.','799.00',2000,NULL,1,'SWAN_All_Purpose_Flour_20251203054421.png'),(77,3,'magnolia-all-purpose-flour','Baking Supplies & Ingredients','Magnolia All Purpose Flour','All-purpose flour is a versatile, finely milled flour made from a blend of hard and soft wheat. It’s suitable for baking breads, cakes, cookies, and for thickening sauces, making it a kitchen staple.','800.00',6000,NULL,1,'Magnolia_All_Purpose_Flour_20251203054620.png'),(78,3,'pillbury-all-purpose-flour','Baking Supplies & Ingredients','PillBury All Purpose Flour','All‑purpose flour that blends hard and soft wheat for reliable performance in nearly any recipe. Excellent for cakes, cookies, breads, batters, sauces, and gravies. Pre‑sifted for convenience and enriched with essential nutrients — a dependable pantry staple for home baking and cooking since 1869.','600.00',50,NULL,1,'PillBury_All_Purpose_Flour_20251203055449.png'),(79,3,'plain-all-purpose-flour','Baking Supplies & Ingredients','Plain All Purpose Flour','A versatile, finely milled flour made from wheat, with no added raising agents. Ideal for everyday baking and cooking, including cakes, cookies, sauces, and pastry doughs. Provides a neutral base and consistent texture for a wide variety of recipes.','400.00',600,NULL,1,'Plain_All_Purpose_Flour_20251203055559.jpg'),(80,3,'cream-all-purpose-flour','Baking Supplies & Ingredients','Cream All Purpose Flour','A soft, finely milled wheat flour with a slightly higher starch content, perfect for light and tender baked goods such as cakes, pastries, and cookies. Its smooth texture helps create soft, delicate, and creamy results in your baking.','400.00',500,NULL,1,'Cream_All_Purpose_Flour_20251203055706.png'),(81,3,'maya-all-purpose-flour','Baking Supplies & Ingredients','Maya All Purpose Flour','A high-quality all-purpose flour ideal for everyday baking and cooking. Perfect for breads, cakes, pastries, and other baked goods, Maya Flour delivers consistent texture and reliable results in every recipe.','599.00',1000,NULL,1,'Maya_All_Purpose_Flour_20251203055801.jpg'),(82,6,'foster-clarks---baking-powder','Baking Supplies & Ingredients','Foster Clarks - Baking Powder','A reliable leavening agent that helps your baked goods rise light and fluffy. Perfect for cakes, cookies, muffins, and other pastries, Foster Clarks Baking Powder ensures consistent, airy results every time.','600.00',789,NULL,1,'Foster_Clarks_-_Baking_Powder_20251203060338.jpg'),(83,6,'moirs---baking-powder','Baking Supplies & Ingredients','Moir\'s - Baking Powder','A trusted leavening agent that helps your cakes, cookies, and pastries rise perfectly every time. Moir’s Baking Powder ensures light, fluffy, and consistent results for all your baking needs.','500.00',700,NULL,1,'Moir\'s_-_Baking_Powder_20251203060436.jpg'),(84,6,'greens---baking-powder','Baking Supplies & Ingredients','Green\'s - Baking Powder','A reliable leavening agent that ensures your baked goods rise light and fluffy. Perfect for cakes, muffins, cookies, and pastries, Green’s Baking Powder delivers consistent and airy results every time.','999.00',999,NULL,1,'Green\'s_-_Baking_Powder_20251203060539.jpg'),(85,6,'bolts-red-mill---baking-powder','Baking Supplies & Ingredients','Bolt\'s Red Mill - Baking Powder','A high-quality, double-acting leavening agent that helps baked goods rise perfectly. Ideal for cakes, muffins, cookies, and pastries, Bob’s Red Mill Baking Powder ensures light, fluffy, and consistent results every time.','400.00',100,NULL,1,'Bolt\'s_Red_Mill_-_Baking_Powder_20251203060651.png'),(86,6,'calumet---baking-powder','Baking Supplies & Ingredients','Calumet - Baking Powder','A trusted leavening agent that helps your baked goods rise light and fluffy. Perfect for cakes, muffins, cookies, and pastries, Calumet Baking Powder delivers consistent, reliable results every time.','150.00',500,NULL,1,'Calumet_-_Baking_Powder_20251203060755.jpg'),(87,6,'bake-best---baking-powder','Baking Supplies & Ingredients','Bake Best - Baking Powder','A dependable leavening agent that helps your cakes, cookies, muffins, and pastries rise perfectly. Bake Best Baking Powder ensures light, fluffy, and consistent results every time.','450.00',200,NULL,1,'Bake_Best_-_Baking_Powder_20251203060850.jpg'),(88,6,'queens---baking-powder','Baking Supplies & Ingredients','Queen\'s - Baking Powder','A reliable leavening agent that ensures your baked goods rise light and fluffy. Perfect for cakes, cookies, muffins, and pastries, Queen Baking Powder delivers consistent and airy results every time.','500.00',400,NULL,1,'Queen\'s_-_Baking_Powder_20251203060941.jpg'),(89,7,'absolute---drinking-water','Coffee, Tea & Beverages','Absolute - Drinking Water','Pure, refreshing, and safe to drink, Absolute Drinking Water provides clean hydration for everyday use. Perfect for drinking, cooking, or mixing with beverages, it ensures quality and freshness in every bottle.','20.00',588,NULL,1,'Absolute_-_Drinking_Water_20251203061431.jpg'),(90,7,'premier---drinking-water','Coffee, Tea & Beverages','Premier - Drinking Water','Clean, crisp, and refreshing, Premier Drinking Water provides safe and pure hydration for everyday use. Ideal for drinking, cooking, or mixing with beverages, it delivers consistent quality in every bottle.','35.00',1000,NULL,1,'Premier_-_Drinking_Water_20251203061623.jpg'),(91,7,'crystal-clear---drinking-water','Coffee, Tea & Beverages','Crystal Clear - Drinking Water','Pure, refreshing, and safe to drink, Crystal Clear Drinking Water provides clean hydration for daily use. Perfect for drinking, cooking, or mixing with beverages, it ensures consistent quality and freshness in every bottle.','40.00',1444,NULL,1,'Crystal_Clear_-_Drinking_Water_20251203061730.jpg'),(92,7,'viva---drinking-water','Coffee, Tea & Beverages','Viva - Drinking Water','Refreshing, pure, and safe for everyday hydration, Viva Drinking Water ensures clean and crisp taste in every sip. Perfect for drinking, cooking, or mixing with beverages, it delivers reliable quality and freshness.','34.00',5000,NULL,1,'Viva_-_Drinking_Water_20251203061827.jpg'),(93,7,'aquafina---drinking-water','Coffee, Tea & Beverages','Aquafina - Drinking Water','Pure, crisp, and refreshing, Aquafina Drinking Water provides clean hydration for daily use. Perfect for drinking, cooking, or mixing with beverages, it ensures consistent quality and freshness in every bottle.','26.00',9999,NULL,1,'Aquafina_-_Drinking_Water_20251203061921.jpg'),(94,7,'pocari-sweet---drinking-water','Coffee, Tea & Beverages','Pocari Sweet - Drinking Water','A refreshing ion supply drink that helps replenish fluids and electrolytes lost through sweat. Pocari Sweat provides quick hydration, making it ideal for sports, workouts, outdoor activities, or hot weather. Light, smooth, and easy to drink, it restores energy and keeps you hydrated throughout the day.','30.00',400,NULL,1,'Pocari_Sweet_-_Drinking_Water_20251203062043.jpg'),(95,7,'evian---drinking-water','Coffee, Tea & Beverages','Evian - Drinking Water','Naturally filtered through the French Alps, Evian Drinking Water delivers a clean, crisp taste with balanced minerals for pure, refreshing hydration. Ideal for everyday drinking, it offers premium quality and smoothness in every bottle.','30.00',3999,NULL,1,'Evian_-_Drinking_Water_20251203062337.jpg'),(96,7,'wilkins-pure---drinking-water','Coffee, Tea & Beverages','Wilkins pure - Drinking Water','Purified through a strict, multi-stage process, Wilkins Pure Drinking Water offers clean, safe, and refreshing hydration. Ideal for daily drinking, cooking, or mixing with beverages, it ensures consistent quality and purity in every bottle.','30.00',598,NULL,1,'Wilkins_pure_-_Drinking_Water_20251203062537.jpg'),(97,7,'nature-spring---drinking-water','Coffee, Tea & Beverages','Nature Spring - Drinking Water','Clean, safe, and refreshing, Nature’s Spring Drinking Water is purified and processed to deliver consistent quality. Ideal for everyday hydration, cooking, or mixing with beverages, it provides a crisp and reliable taste in every bottle.','20.00',1312,NULL,1,'Nature_Spring_-_Drinking_Water_20251203062701.jpg');

/*Table structure for table `product_click` */

DROP TABLE IF EXISTS `product_click`;

CREATE TABLE `product_click` (
  `click_id` bigint(20) NOT NULL AUTO_INCREMENT,
  `click_timestamp` datetime DEFAULT current_timestamp(),
  `product_id` int(11) NOT NULL,
  `account_id` int(11) DEFAULT NULL,
  `source_page` varchar(100) DEFAULT NULL,
  `session_id` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`click_id`),
  KEY `product_id` (`product_id`),
  KEY `account_id` (`account_id`),
  CONSTRAINT `product_click_ibfk_1` FOREIGN KEY (`product_id`) REFERENCES `product` (`product_id`),
  CONSTRAINT `product_click_ibfk_2` FOREIGN KEY (`account_id`) REFERENCES `account` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `product_click` */

/*Table structure for table `product_review` */

DROP TABLE IF EXISTS `product_review`;

CREATE TABLE `product_review` (
  `review_id` int(11) NOT NULL AUTO_INCREMENT,
  `product_id` int(11) NOT NULL,
  `reviewer_account_id` int(11) NOT NULL,
  `order_item_id` int(11) DEFAULT NULL,
  `rating` tinyint(4) NOT NULL CHECK (`rating` >= 1 and `rating` <= 5),
  `comment` text DEFAULT NULL,
  `review_date` datetime DEFAULT current_timestamp(),
  `is_approved` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`review_id`),
  UNIQUE KEY `order_item_id` (`order_item_id`),
  KEY `product_id` (`product_id`),
  KEY `reviewer_account_id` (`reviewer_account_id`),
  CONSTRAINT `product_review_ibfk_1` FOREIGN KEY (`product_id`) REFERENCES `product` (`product_id`),
  CONSTRAINT `product_review_ibfk_2` FOREIGN KEY (`reviewer_account_id`) REFERENCES `account` (`account_id`),
  CONSTRAINT `product_review_ibfk_3` FOREIGN KEY (`order_item_id`) REFERENCES `order_items` (`order_item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `product_review` */

/*Table structure for table `rider_application` */

DROP TABLE IF EXISTS `rider_application`;

CREATE TABLE `rider_application` (
  `rider_app_id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) NOT NULL,
  `license_number` varchar(100) NOT NULL,
  `vehicle_type` enum('Motorcycle','Bicycle','Van') NOT NULL,
  `plate_number` varchar(50) NOT NULL,
  `documents_path` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`documents_path`)),
  `otp_code` varchar(6) DEFAULT NULL,
  `otp_expiry` datetime DEFAULT NULL,
  `otp_verified` tinyint(1) DEFAULT 0,
  `otp_method` enum('Email','SMS') DEFAULT 'Email',
  `application_date` datetime DEFAULT current_timestamp(),
  `status` enum('Pending OTP','Pending Review','Approved','Rejected') NOT NULL DEFAULT 'Pending OTP',
  `review_notes` text DEFAULT NULL,
  `date_approved` datetime DEFAULT NULL,
  PRIMARY KEY (`rider_app_id`),
  UNIQUE KEY `account_id` (`account_id`),
  UNIQUE KEY `plate_number` (`plate_number`),
  CONSTRAINT `rider_application_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `rider_application` */

/*Table structure for table `rider_rating` */

DROP TABLE IF EXISTS `rider_rating`;

CREATE TABLE `rider_rating` (
  `rider_rating_id` int(11) NOT NULL AUTO_INCREMENT,
  `rider_account_id` int(11) NOT NULL,
  `rater_account_id` int(11) NOT NULL,
  `order_id` int(11) NOT NULL,
  `rating` tinyint(4) NOT NULL CHECK (`rating` >= 1 and `rating` <= 5),
  `comment` text DEFAULT NULL,
  `rating_date` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`rider_rating_id`),
  UNIQUE KEY `order_id` (`order_id`),
  KEY `rider_account_id` (`rider_account_id`),
  KEY `rater_account_id` (`rater_account_id`),
  CONSTRAINT `rider_rating_ibfk_1` FOREIGN KEY (`rider_account_id`) REFERENCES `account` (`account_id`),
  CONSTRAINT `rider_rating_ibfk_2` FOREIGN KEY (`rater_account_id`) REFERENCES `account` (`account_id`),
  CONSTRAINT `rider_rating_ibfk_3` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `rider_rating` */

/*Table structure for table `seller_application` */

DROP TABLE IF EXISTS `seller_application`;

CREATE TABLE `seller_application` (
  `seller_app_id` int(11) NOT NULL AUTO_INCREMENT,
  `account_id` int(11) NOT NULL,
  `business_name` varchar(255) NOT NULL,
  `dti_registration_number` varchar(100) DEFAULT NULL,
  `business_address` varchar(255) DEFAULT NULL,
  `documents_path` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`documents_path`)),
  `otp_code` varchar(6) DEFAULT NULL,
  `otp_expiry` datetime DEFAULT NULL,
  `otp_verified` tinyint(1) DEFAULT 0,
  `otp_method` enum('Email','SMS') DEFAULT 'Email',
  `application_date` datetime DEFAULT current_timestamp(),
  `status` enum('Pending OTP','Pending Review','Approved','Rejected') NOT NULL DEFAULT 'Pending OTP',
  `review_notes` text DEFAULT NULL,
  `date_approved` datetime DEFAULT NULL,
  PRIMARY KEY (`seller_app_id`),
  UNIQUE KEY `account_id` (`account_id`),
  CONSTRAINT `seller_application_ibfk_1` FOREIGN KEY (`account_id`) REFERENCES `account` (`account_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `seller_application` */

insert  into `seller_application`(`seller_app_id`,`account_id`,`business_name`,`dti_registration_number`,`business_address`,`documents_path`,`otp_code`,`otp_expiry`,`otp_verified`,`otp_method`,`application_date`,`status`,`review_notes`,`date_approved`) values (1,4,'Broom Clad Trading',NULL,'456 Test Street, Example City',NULL,NULL,NULL,1,'Email','2025-12-03 03:44:56','Approved','Manual approval for testing','2025-12-03 03:44:56'),(2,3,'Micah Coffee Co.',NULL,'123 Coffee Lane, Sample City',NULL,NULL,NULL,1,'Email','2025-12-03 03:57:01','Approved','Manual approval for testing - Account 3','2025-12-03 03:57:01'),(3,6,'Andrew\'s Castillo Shop',NULL,'Seller Default Address',NULL,NULL,NULL,1,'Email','2025-12-03 06:01:27','Approved','Auto-approved on login for testing.','2025-12-03 06:01:27'),(4,7,'Nath\'s Ramos Shop',NULL,'Seller Default Address',NULL,NULL,NULL,1,'Email','2025-12-03 06:13:20','Approved','Auto-approved on login for testing.','2025-12-03 06:13:20');

/*Table structure for table `seller_rating` */

DROP TABLE IF EXISTS `seller_rating`;

CREATE TABLE `seller_rating` (
  `seller_rating_id` int(11) NOT NULL AUTO_INCREMENT,
  `seller_account_id` int(11) NOT NULL,
  `rater_account_id` int(11) NOT NULL,
  `order_id` int(11) NOT NULL,
  `rating` tinyint(4) NOT NULL CHECK (`rating` >= 1 and `rating` <= 5),
  `comment` text DEFAULT NULL,
  `rating_date` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`seller_rating_id`),
  UNIQUE KEY `order_id` (`order_id`),
  KEY `seller_account_id` (`seller_account_id`),
  KEY `rater_account_id` (`rater_account_id`),
  CONSTRAINT `seller_rating_ibfk_1` FOREIGN KEY (`seller_account_id`) REFERENCES `account` (`account_id`),
  CONSTRAINT `seller_rating_ibfk_2` FOREIGN KEY (`rater_account_id`) REFERENCES `account` (`account_id`),
  CONSTRAINT `seller_rating_ibfk_3` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `seller_rating` */

/*Table structure for table `store` */

DROP TABLE IF EXISTS `store`;

CREATE TABLE `store` (
  `store_id` int(11) NOT NULL AUTO_INCREMENT,
  `owner_account_id` int(11) NOT NULL,
  `store_name` varchar(255) NOT NULL,
  `slug` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `address_line` varchar(255) NOT NULL,
  `city` varchar(100) NOT NULL,
  `contact_phone` varchar(20) DEFAULT NULL,
  `is_open` tinyint(1) DEFAULT 1,
  `date_opened` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`store_id`),
  UNIQUE KEY `owner_account_id` (`owner_account_id`),
  UNIQUE KEY `slug` (`slug`),
  CONSTRAINT `store_ibfk_1` FOREIGN KEY (`owner_account_id`) REFERENCES `account` (`account_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `store` */

insert  into `store`(`store_id`,`owner_account_id`,`store_name`,`slug`,`description`,`address_line`,`city`,`contact_phone`,`is_open`,`date_opened`) values (1,4,'Broom Clad Kitchen Supplies','broom-clad-kitchen-supplies',NULL,'456 Test Street, Example City','Manila',NULL,1,'2025-12-03 03:45:05'),(2,3,'Micah Coffee Blends','micah-coffee-blends',NULL,'123 Coffee Lane','Makati',NULL,1,'2025-12-03 03:57:01'),(3,6,'Andrew\'s Castillo Shop','andrews-castillo-shop',NULL,'Seller Default Address','Default City',NULL,1,'2025-12-03 06:01:27'),(4,7,'Nath\'s Ramos Shop','naths-ramos-shop',NULL,'Seller Default Address','Default City',NULL,1,'2025-12-03 06:13:20');

/*Table structure for table `transaction` */

DROP TABLE IF EXISTS `transaction`;

CREATE TABLE `transaction` (
  `transaction_id` int(11) NOT NULL AUTO_INCREMENT,
  `order_id` int(11) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `gateway_fee` decimal(10,2) DEFAULT 0.00,
  `payment_method` varchar(50) DEFAULT NULL,
  `gateway_tx_id` varchar(255) DEFAULT NULL,
  `payment_reference` varchar(255) DEFAULT NULL,
  `status` enum('Success','Failed','Pending','Refunded') NOT NULL,
  `transaction_date` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`transaction_id`),
  UNIQUE KEY `order_id` (`order_id`),
  UNIQUE KEY `gateway_tx_id` (`gateway_tx_id`),
  CONSTRAINT `transaction_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

/*Data for the table `transaction` */

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
