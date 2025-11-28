-- Table: virtual_machines (虚拟机实例表)
CREATE TABLE virtual_machines (
    id SERIAL PRIMARY KEY,  -- 唯一标识符，自动增长
    name VARCHAR(255) NOT NULL,  -- 虚拟机名称
    os VARCHAR(100) NOT NULL,    -- 操作系统 (例如: 'Ubuntu', 'Windows Server')
    storage_id INTEGER,          -- 关联的存储资源 ID (外键)
    checksum CHAR(32) NOT NULL,  -- MD5 校验和 (由 name + os + storage_id 组合计算)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- 创建时间
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP -- 更新时间
);

-- Table: storages (存储资源表)
CREATE TABLE storages (
    id SERIAL PRIMARY KEY,  -- 唯一标识符，自动增长
    name VARCHAR(255) NOT NULL UNIQUE,  -- 存储名称，不允许重复
    capacity VARCHAR(50) NOT NULL,      -- 存储容量 (例如: '100G', '1TB')
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- 创建时间
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP , -- 更新时间,
    v_id INTEGER,
     -- 外键约束：确保 v_id 引用 virtual_machines 表中的 id
    CONSTRAINT fk_storage
        FOREIGN KEY (v_id)
        REFERENCES virtual_machines (id)
        ON DELETE SET NULL  -- 如果 virtual_machines 表中的记录被删除，此处 storage_id 设为 NULL
);