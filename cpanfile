# cpanfile - 项目依赖描述文件

# 指定所需的 Perl 版本 (根据您的项目需求调整)
requires 'perl', '5.010'; 

# --- 运行时依赖 (Runtime Dependencies) ---
# 这是您的业务代码（lib/）在运行时需要的模块
requires 'DBI', '>= 1.643'; # 数据库接口
# 其他您的业务模块可能需要的，例如：
requires 'Template', '>= 2.29'; # 如果使用了 Template Toolkit

# --- 测试依赖 (Testing Dependencies) ---
# 这些是只在运行测试（t/）时需要的模块
on 'test' => sub {
    # Test::Class 生态系统
    requires 'Test::Class', '>= 0.51';
    requires 'Test::Class::Load', '>= 0.51';
    
    # Mocking 和高级测试工具
    requires 'Test::More', '>= 1.302183'; # 确保使用较新版本
    requires 'Test::MockModule', '>= 0.16';
    requires 'Test::Fatal', '>= 0.010';
    
    # 其他常用的测试工具（可选，但推荐）
    requires 'Test::Exception', '>= 0.43'; 
};