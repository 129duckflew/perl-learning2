package Local::VirtualMachine;
use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use Local::DB;
use Local::Storage;

# 预定义的操作系统
my %ALLOWED_OS = map { $_ => 1 } qw(Ubuntu CentOS Windows Server Debian);

sub new {
    my ($class, %args) = @_;
    my $self = {
        id           => $args{id},
        name         => $args{name},
        os           => $args{os},
        # 字段修改：从 storage_id 变为 storage_ids (数组引用)
        storage_ids  => $args{storage_ids} || [], 
        checksum     => $args{checksum},
        created_at   => $args{created_at},
        updated_at   => $args{updated_at},
        
        # 用于前端显示的属性
        storage_names => $args{storage_names}, 
        storage_ids_csv => $args{storage_ids_csv},
        
        # 移除 _storage_obj (因为现在是多个)
    };
    
    # 确保 storage_ids 是数组引用
    if (ref $self->{storage_ids} ne 'ARRAY') {
        # 如果从 form/DB 传入的单值，将其包装成数组
        $self->{storage_ids} = [$self->{storage_ids}] if defined $self->{storage_ids} && $self->{storage_ids};
    }
    
    bless $self, $class;
    return $self;
}

sub find_all {
    my ($class) = @_;
    my $dbh = Local::DB::get_handle();
    
    # 1. 查询所有虚拟机
    my $vm_sql = "SELECT * FROM virtual_machines ORDER BY id DESC";
    my $vms_hash = $dbh->selectall_hashref($vm_sql, 'id');
    
    # 2. 查询所有存储关联信息（通过 v_id 字段反查）
    my $storage_sql = "SELECT id, name, v_id FROM storages WHERE v_id IS NOT NULL";
    my $sth = $dbh->prepare($storage_sql);
    $sth->execute();

    # 3. 将存储信息映射到对应的 VM
    while (my $row = $sth->fetchrow_hashref) {
        my $vm_id = $row->{v_id};
        next unless $vms_hash->{$vm_id};
        
        # 为每个 VM 收集关联的存储 ID 和名称
        push @{ $vms_hash->{$vm_id}->{storage_ids} ||= [] }, $row->{id};
        push @{ $vms_hash->{$vm_id}->{storage_names} ||= [] }, $row->{name};
    }
    
    # 4. 实例化 VM 对象
    my @list;
    foreach my $id (sort { $b <=> $a } keys %$vms_hash) {
        my $vm_data = $vms_hash->{$id};
        
        # 格式化前端显示需要的字符串
        $vm_data->{storage_names} = [ @{ $vm_data->{storage_names} || [] } ];
        $vm_data->{storage_ids_csv} = join(', ', @{ $vm_data->{storage_ids} || [] });
        
        push @list, $class->new(%$vm_data);
    }
    
    return \@list;
}

sub find {
    my ($class, $id) = @_;
    # 为了简化，此处 find 不包含关联存储查询，只返回 VM 基本信息
    my $dbh = Local::DB::get_handle();
    my $row = $dbh->selectrow_hashref("SELECT * FROM virtual_machines WHERE id = ?", undef, $id);
    return undef unless $row;
    return $class->new(%$row);
}

sub save {
    my ($self) = @_;

    # 1. 验证 OS (保持不变)
    die "Invalid OS: $self->{os}" unless $ALLOWED_OS{$self->{os}};
    
    # 2. 计算 Checksum (保持不变)
    my $data_string = $self->{name} . $self->{os} . ($self->{storage_ids_csv} || ''); # Checksum 依赖于所有 IDs
    $self->{checksum} = md5_hex($data_string);

    my $dbh = Local::DB::get_handle();
    
    # 3. 校验所选存储是否已被绑定 (核心校验逻辑)
    if ($self->{storage_ids} && @{ $self->{storage_ids} }) {
        my $placeholders = join(',', ('?') x @{ $self->{storage_ids} });
        # 查找 v_id 不为空，且 v_id 不是当前 VM 自身的 ID 的存储
        my $sql = "SELECT name FROM storages WHERE id IN ($placeholders) AND v_id IS NOT NULL AND v_id != ?";
        
        # 将 VM ID 也加入参数列表，用于排除自身 ID
        my @params = (@{ $self->{storage_ids} }, $self->{id} || 0); 
        
        my $conflict_name = $dbh->selectrow_array($sql, undef, @params);
        
        if ($conflict_name) {
            # 找到冲突，抛出异常
            die "存储 '$conflict_name' 已被其他虚拟机绑定";
        }
    }

    $dbh->begin_work; # 开启事务，确保 VM 和 Storage 更新的原子性
    
    eval {
        if ($self->{id}) {
            # 4.1. 更新虚拟机 (保持不变)
            my $sql = "UPDATE virtual_machines SET name=?, os=?, checksum=?, updated_at=NOW() WHERE id=?";
            $dbh->do($sql, undef, $self->{name}, $self->{os}, $self->{checksum}, $self->{id});

            # 4.2. **解绑**原有存储 (将原有 v_id 设为 NULL)
            $dbh->do("UPDATE storages SET v_id=NULL WHERE v_id=?", undef, $self->{id});
        } else {
            # 4.3. 新建虚拟机 (保持不变)
            my $sql = "INSERT INTO virtual_machines (name, os, checksum) VALUES (?, ?, ?) RETURNING id, created_at";
            my $row = $dbh->selectrow_arrayref($sql, undef, $self->{name}, $self->{os}, $self->{checksum});
            ($self->{id}, $self->{created_at}) = @$row;
        }

        # 5. 绑定新存储 (将新存储的 v_id 设为当前 VM 的 ID)
        if ($self->{storage_ids} && @{ $self->{storage_ids} }) {
            my $placeholders = join(',', ('?') x @{ $self->{storage_ids} });
            my $sql = "UPDATE storages SET v_id=? WHERE id IN ($placeholders)";
            $dbh->do($sql, undef, $self->{id}, @{ $self->{storage_ids} });
        }
        
        $dbh->commit; # 提交事务
    };
    
    if ($@) {
        $dbh->rollback; # 发生错误，回滚事务
        die $@; # 重新抛出错误
    }
    
    return $self->{id};
}

sub delete {
    my ($self) = @_;
    return unless $self->{id};
    
    my $dbh = Local::DB::get_handle();
    $dbh->begin_work;

    eval {
        # 1. 解绑所有关联的存储 (将所有关联存储的 v_id 设为 NULL)
        $dbh->do("UPDATE storages SET v_id=NULL WHERE v_id=?", undef, $self->{id});

        # 2. 删除虚拟机记录
        $dbh->do("DELETE FROM virtual_machines WHERE id = ?", undef, $self->{id});
        
        $dbh->commit;
    };
    
    if ($@) {
        $dbh->rollback;
        die $@;
    }
}

# Getters for Template Toolkit (已更新以支持多存储显示)
sub id { shift->{id} }
sub name { shift->{name} }
sub os { shift->{os} }
# 以下两个 getter 替换了原有的 storage_id/storage_name
sub storage_names { 
    my $self = shift;
    return $self->{storage_names} ? join(', ', @{ $self->{storage_names} }) : 'None'; 
}
sub storage_ids_csv { shift->{storage_ids_csv} } 
sub checksum { shift->{checksum} }
sub created_at { shift->{created_at} }

sub storage_id { 
    my $self = shift;
    return $self->{storage_ids} && ref $self->{storage_ids} eq 'ARRAY' ? $self->{storage_ids}[0] : undef;
}

sub storage_name { 
    my $self = shift;
    # 捕获 $self 后，只对 $self 进行操作，确保它是一个有效的哈希引用
    return $self->{storage_names} && ref $self->{storage_names} eq 'ARRAY' ? $self->{storage_names}[0] : undef; 
}
1;