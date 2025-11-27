#!/usr/bin/perl -w
use strict;
use warnings;
use CGI;
use FindBin;
use lib "$FindBin::Bin/lib"; # 引用本地 lib
use Template;
use Local::VirtualMachine;
use Local::Storage;

my $q = CGI->new;
print $q->header(-charset => 'utf-8');

# 初始化 Template Toolkit
my $tt = Template->new({
    INCLUDE_PATH => "$FindBin::Bin/templates",
    ENCODING     => 'utf8',
    DIE_ON_ERROR => 1, # 强制在模板内部出现错误时抛出 Perl 异常
    DEBUG        => 1, # 开启调试信息 (可选，但推荐)
});

# 简单的路由分发
my $action = $q->param('action') || 'list';
my $vars = {};

eval {
    if ($action eq 'list') {
        # 显示列表 (Dashboard)
        $vars->{vms} = Local::VirtualMachine->find_all();
        $vars->{storages} = Local::Storage->find_all(); # 用于新建 VM 的下拉菜单
    }
    elsif ($action eq 'create_storage') {
        my $name = $q->param('name');
        my $cap  = $q->param('capacity');
        
        die "Storage Name is required" unless $name;
        
        my $sto = Local::Storage->new(name => $name, capacity => $cap);
        $sto->save();
        $vars->{message} = "Storage '$name' created successfully!";
        
        # Reload list
        $vars->{vms} = Local::VirtualMachine->find_all();
        $vars->{storages} = Local::Storage->find_all();
    }
    elsif ($action eq 'create_vm') {
        my $name    = $q->param('name');
        my $os      = $q->param('os');
        my @sto_ids = $q->param('storage_ids');
        # 过滤掉可能的空值 (防御性编程)
        @sto_ids = grep { defined $_ && $_ ne '' } @sto_ids;
        # 后端验证
        die "VM Name is required" unless $name;
        die "Operating System is required" unless $os;

        my $vm = Local::VirtualMachine->new(
            name => $name, 
            os => $os, 
            # 修正 3: 传递 'storage_ids' (复数) 且传递数组引用 (Array Ref)
            storage_ids => \@sto_ids
        );
        $vm->save(); # 这里会触发 Checksum 计算
        
        $vars->{message} = "VM '$name' created with Checksum: " . $vm->checksum;
        
        # Reload list
        $vars->{vms} = Local::VirtualMachine->find_all();
        $vars->{storages} = Local::Storage->find_all();
    }
    elsif ($action eq 'delete_vm') {
        my $id = $q->param('id');
        if ($id) {
            my $vm = Local::VirtualMachine->new(id => $id);
            $vm->delete();
            $vars->{message} = "VM deleted. Storage disassociated (if any).";
        }
        $vars->{vms} = Local::VirtualMachine->find_all();
        $vars->{storages} = Local::Storage->find_all();
    }
    else {
        die "Unknown action";
    }
    
    # 渲染视图
    $tt->process('index.tt', $vars) || die $tt->error();
};

if ($@) {
    # 错误处理视图
    $tt->process('error.tt', { error => $@ }) || die $tt->error();
}