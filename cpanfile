requires 'perl', '5.010'; 
requires 'DBI', '>= 1.643'; # 数据库接口
requires 'Template', '>= 2.29'; # 如果使用了 Template Toolkit
requires 'CGI', '>= 3.63';      # 如果是 CGI 应用
# DBD PG
requires 'DBD::Pg', '>= 3.18.0'; # PostgreSQL 数据库驱动
# --- 测试依赖 (Testing Dependencies) ---
on 'test' => sub {
    # Test::Class 生态系统
    requires 'Test::Class', '>= 0.51';
    requires 'Test::Class::Load', '>= 0.51';
    
    # Mocking 和高级测试工具
    requires 'Test::More', '>= 1.302183'; # 确保使用较新版本
    requires 'Test::MockModule', '>= 0.16';
    requires 'Test::Fatal', '>= 0.010';
    requires 'Test::MockObject', '>= 1.201';
    # 其他常用的测试工具（可选，但推荐）
    requires 'Test::Exception', '>= 0.43'; 
};