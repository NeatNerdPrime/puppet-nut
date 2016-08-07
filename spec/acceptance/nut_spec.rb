require 'spec_helper_acceptance'

describe 'nut' do

  case fact('osfamily')
  when 'OpenBSD'
    conf_dir = '/etc/nut'
    group    = 'wheel'
    mode     = 600
    owner    = '_ups'
    service  = 'upsd'
  when 'RedHat'
    conf_dir = '/etc/ups'
    group    = 'nut'
    mode     = 640
    owner    = 'root'
    service  = 'nut-server'
  end

  it 'should work with no errors' do

    pp = <<-EOS
      Package {
        source => $::osfamily ? {
          'OpenBSD' => "http://ftp.openbsd.org/pub/OpenBSD/${::operatingsystemrelease}/packages/${::architecture}/",
          default   => undef,
        },
      }

      include ::nut

      ::nut::ups { 'dummy':
        driver => 'dummy-ups',
        port   => 'sua1000i.dev',
      }

      file { '#{conf_dir}/sua1000i.dev':
        ensure => file,
        owner  => 0,
        group  => 0,
        mode   => '0644',
        source => '/root/sua1000i.dev',
        before => ::Nut::Ups['dummy'],
      }

      ::nut::user { 'test':
        password => 'password',
        upsmon   => 'master',
      }
    EOS

    apply_manifest(pp, :catch_failures => true)
    apply_manifest(pp, :catch_changes  => true)
  end

  describe file("#{conf_dir}/ups.conf") do
    it { should be_file }
    it { should be_mode mode }
    it { should be_owned_by owner }
    it { should be_grouped_into group }
    its(:content) do
      should eq <<-EOS.gsub(/^ +/, '')
        # !!! Managed by Puppet !!!
        [dummy]
        	driver = "dummy-ups"
        	port = "sua1000i.dev"
      EOS
    end
  end

  describe file("#{conf_dir}/upsd.users") do
    it { should be_file }
    it { should be_mode mode }
    it { should be_owned_by owner }
    it { should be_grouped_into group }
    its(:content) do
      should eq <<-EOS.gsub(/^ +/, '')
        # !!! Managed by Puppet !!!
        [test]
        	password = password
        	upsmon master
      EOS
    end
  end

  describe service(service) do
    it { should be_enabled }
    it { should be_running }
  end

  describe command('upsc dummy') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should match /^ups\.model: Smart-UPS 1000$/ }
  end
end
