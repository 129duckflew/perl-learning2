use strict;
use warnings;

use Test::Class::Load 't/tests'; 
use Test::Class; 
use Test::More;


# 运行所有被加载的测试类
Test::Class->runtests;

