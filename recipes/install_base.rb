# install package common to package and source install
case node[:platform]
when "redhat","centos","scientific","fedora","suse","amazon"
  packages = %w[apr apr-util pcre curl]
when "ubuntu","debian"
  packages = %w[libapr1 libaprutil1 libpcre3 libxml2 libcurl3]
when "arch"
  # OH NOES!
end
packages.each {|p| package p}

# FIXME: ignoring lua for right now
# make optional in the future

if node[:mod_security][:from_source]
  # COMPILE FROM SOURCE
  
  #install required libs
  case node[:platform]
  when "redhat","centos","scientific","fedora","suse","amazon"
    packages = %w[pcre-devel httpd-devel libxml2-devel curl-devel]
  when "ubuntu","debian"
    packages = %w[apache2-dev libxml2-dev libcurl3-dev]
  when "arch"
    # OH NOES!
  end
  packages.each {|p| package p}
  
  directory "#{node[:mod_security][:dir]}/source" do
    recursive true
  end

  source_code = "#{node[:mod_security][:dir]}/source/#{node[:mod_security][:source_file]}"
  remote_file source_code do
    action :create_if_missing
    source node[:mod_security][:source_dl_url]
    mode "0644"
    #checksum node[:mod_security][:source_checksum] seems to get ignored? FIXME
    backup false
  end

  bash "install_mod_security" do
    action :nothing
    code <<-EOH
      cd #{node[:mod_security][:dir]}/source
      tar -zxf #{node[:mod_security][:source_file]}
      cd modsecurity-apache_#{node[:mod_security][:source_version]}
      ./configure
      make
      make mlogc
      make install
    EOH
    subscribes :run, resources(:remote_file => source_code), :immediately
  end

  # setup apache module loading
  apache_module "unique_id"
  # we have to manage our own loading
  template "#{node[:apache][:dir]}/mods-enabled/mod-security.load" do
    owner node[:apache][:user]
    group node[:apache][:group]
    mode 0644
    #backup false
    notifies :restart, resources(:service => "apache2"), :delayed
  end
  
else
  # INSTALL FROM PACKAGE
  
  case node[:platform]
  when "redhat","centos","scientific","fedora","suse","amazon"
    package "mod_security"
  when "ubuntu","debian"
    package "libapache-mod-security"
  when "arch"
    # OH NOES!
  end
end

directory "#{node[:mod_security][:rules]}" do
  recursive true
end

template "mod_security" do
  path "#{node[:apache][:dir]}/conf.d/mod_security"
  source "mod_security.erb"
  owner node[:apache][:user]
  group node[:apache][:group]
  mode 0644
  backup false
  notifies :restart, resources(:service => "apache2")
end
