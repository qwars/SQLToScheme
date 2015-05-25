#!/usr/bin/perl -w
# sql-test.pl --- Разбор SQL - запросов в схему и Обратно
# Author: Alexandr Selunin <aka.qwars@gmail.com>
# Created: 22 Apr 2015
# Version: 0.01

use warnings;
use strict;
use feature qw/say/;
use Data::Dumper;
$Data::Dumper::Indent = 1;

use SQLAbstractObject;
my $sqlo = SQLAbstractObject->new();

my $sql = q/SELECT SQL_CALC_FOUND_ROWS `features`.*, `features_good`.`value`, `features_good`.`id` AS `fgid`, `features_good`.`unit` FROM `features_good` RIGHT OUTER JOIN ( SELECT `features`.* FROM `features` JOIN ( SELECT SQL_SMALL_RESULT `features_good`.`fid`, `features_good`.`gid` FROM `features_good` JOIN ( SELECT SQL_SMALL_RESULT `gid` FROM `categories_good` JOIN ( SELECT SQL_SMALL_RESULT `cid` FROM `categories_good` WHERE `categories_good`.`gid` = 123 ) AS cit ON cit.`cid` = `categories_good`.`cid` GROUP BY `categories_good`.`gid` ) AS `gctg` ON `gctg`.`gid` = `features_good`.`gid` GROUP BY `features_good`.`fid` ) AS `ftr` ON `ftr`.`fid` = `features`.`id` ) AS `features` ON `features_good`.`fid` = `features`.`id` AND `features_good`.`gid` = 123/; 
# $sql = q/SELECT DATE_ADD( NOW(), INTERVAL '-3' MINUTES ) AS t/;
# $sql = q/SELECT NOW() AS t/;
# $sql = q/SELECT count(`id`) AS t FROM `product`/;
# $sql = q/SELECT *, IF( `changes` > 0, 1, 0 ) AS t FROM `product`/;
# $sql = q/SELECT MOD(29,9)/;
# $sql = q/SELECT IF( count(`id`) IS NULL, 1,0 ) AS t FROM `product` GROUP BY `name`/;
# $sql = q/SELECT * FROM `product` WHERE `price` BETWEEN 12 AND 13 GROUP BY `name`/;
# $sql = q/SELECT * FROM `product` WHERE `price` NOT BETWEEN 12 AND 13 GROUP BY `name`/;
# $sql = q/SELECT * FROM `product` WHERE `price` IN( 234,567,890 )/;
# $sql = q~SELECT COALESCE(NULL,NULL,NULL) AS ct, COUNT(`id`)~;
# $sql = q~SELECT 1 IS NULL, 0 IS NULL, NULL IS NULL~;
# $sql = q~SELECT NOT 10~;
# $sql = q~SELECT IFNULL(expr1,expr2)~;
# $sql = q~SELECT CASE 1 WHEN 1 THEN "one"~;
# $sql = q~SELECT CASE WHEN 1>0 THEN "true" ELSE "false" END~; 
# $sql = q~SELECT CASE BINARY "B" WHEN "a" THEN 1 WHEN "b" THEN 2 END~;
# $sql = q~SELECT IF(STRCMP('test','test1'),'no','yes')~;
# $sql = q~SELECT ASCII('2')~;
# $sql = q~SELECT ORD('2')~;
# $sql = q~SELECT  CONV(10+"10"+'10'+0xa,10,10)~; # FIX
# $sql = q~SELECT CHAR(77,121,83,81,'76')~;
# $sql = q~SELECT CONCAT('My', 'S', 'QL')~; # FIX
# $sql = q~SELECT CONCAT_WS('My', 'S', 'QL')~; # FIX
# $sql = q~SELECT LOCATE('bar', 'foobarbar')~;
# $sql = q~SELECT  MATCH (col1,col2) AGAINST (expr)~; 
$sql = q/SELECT * FROM `features` JOIN ( SELECT `fid` FROM `features_product` WHERE `gid` = ~ID~ ) AS `f` ON `f`.`fid` = `features`.`id`'/;

my $object = $sqlo->to_object( $sql );
my $stmt = $sqlo->to_statement( $object );

say Dumper $object;
say Dumper $stmt;

my ( $stmt, @bind ) = $sqlo->to_request( $object, { ID => 35 } );

say Dumper( $stmt, @bind );


__END__
