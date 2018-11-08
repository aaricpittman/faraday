shared_examples 'initializer with url' do
  context 'with simple url' do
    let(:address) { 'http://sushi.com' }

    it { expect(subject.host).to eq('sushi.com') }
    it { expect(subject.port).to eq(80) }
    it { expect(subject.scheme).to eq('http') }
    it { expect(subject.path_prefix).to eq('/') }
    it { expect(subject.params).to eq({}) }
  end

  context 'with complex url' do
    let(:address) { 'http://sushi.com:815/fish?a=1' }

    it { expect(subject.port).to eq(815) }
    it { expect(subject.path_prefix).to eq('/fish') }
    it { expect(subject.params).to eq({ 'a' => '1' }) }
  end
end

RSpec.describe Faraday::Connection do
  let(:conn) { Faraday::Connection.new(url, options) }
  let(:url) { nil }
  let(:options) { {} }

  describe '.new' do
    subject { conn }

    context 'with implicit url param' do
      # Faraday::Connection.new('http://sushi.com')
      let(:url) { address }

      it_behaves_like 'initializer with url'
    end

    context 'with explicit url param' do
      # Faraday::Connection.new(url: 'http://sushi.com')
      let(:url) { { url: address } }

      it_behaves_like 'initializer with url'
    end

    context 'with custom builder' do
      let(:custom_builder) { Faraday::RackBuilder.new }
      let(:options) { { builder: custom_builder } }

      it { expect(subject.builder).to eq(custom_builder) }
    end

    context 'with custom params' do
      let(:options) { { params: { a: 1 } } }

      it { expect(subject.params).to eq({ 'a' => 1 }) }
    end

    context 'with custom params and params in url' do
      let(:url) { 'http://sushi.com/fish?a=1&b=2' }
      let(:options) { { params: { a: 3 } } }
      it { expect(subject.params).to eq({ 'a' => 3, 'b' => '2' }) }
    end

    context 'with custom headers' do
      let(:options) { { headers: { user_agent: 'Faraday' } } }

      it { expect(subject.headers['User-agent']).to eq('Faraday') }
    end
  end

  describe 'basic_auth' do
    subject { conn }

    context 'calling the #basic_auth method' do
      before { subject.basic_auth 'Aladdin', 'open sesame' }

      it { expect(subject.headers['Authorization']).to eq('Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==') }
    end

    context 'adding basic auth info to url' do
      let(:url) { 'http://Aladdin:open%20sesame@sushi.com/fish' }

      it { expect(subject.headers['Authorization']).to eq('Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==') }
    end
  end

  describe '#token_auth' do
    before { subject.token_auth('abcdef', nonce: 'abc') }

    it { expect(subject.headers['Authorization']).to eq('Token nonce="abc", token="abcdef"') }
  end

  describe '#build_exclusive_url' do
    context 'with relative path' do
      subject { conn.build_exclusive_url('sake.html') }

      it 'uses connection host as default host' do
        conn.host = 'sushi.com'
        expect(subject.host).to eq('sushi.com')
        expect(subject.scheme).to eq('http')
      end

      it do
        conn.path_prefix = '/fish'
        expect(subject.path).to eq('/fish/sake.html')
      end

      it do
        conn.path_prefix = '/'
        expect(subject.path).to eq('/sake.html')
      end

      it do
        conn.path_prefix = 'fish'
        expect(subject.path).to eq('/fish/sake.html')
      end

      it do
        conn.path_prefix = '/fish/'
        expect(subject.path).to eq('/fish/sake.html')
      end
    end

    context 'with absolute path' do
      subject { conn.build_exclusive_url('/sake.html') }

      after { expect(subject.path).to eq('/sake.html') }

      it { conn.path_prefix = '/fish' }
      it { conn.path_prefix = '/' }
      it { conn.path_prefix = 'fish' }
      it { conn.path_prefix = '/fish/' }
    end

    context 'with complete url' do
      subject { conn.build_exclusive_url('http://sushi.com/sake.html?a=1') }

      it { expect(subject.scheme).to eq('http') }
      it { expect(subject.host).to eq('sushi.com') }
      it { expect(subject.port).to eq(80) }
      it { expect(subject.path).to eq('/sake.html') }
      it { expect(subject.query).to eq('a=1') }
    end

    it 'overrides connection port for absolute url' do
      conn.port = 23
      uri = conn.build_exclusive_url('http://sushi.com')
      expect(uri.port).to eq(80)
    end

    it 'does not add ending slash given nil url' do
      conn.url_prefix = 'http://sushi.com/nigiri'
      uri = conn.build_exclusive_url
      expect(uri.path).to eq('/nigiri')
    end

    it 'does not add ending slash given empty url' do
      conn.url_prefix = 'http://sushi.com/nigiri'
      uri = conn.build_exclusive_url('')
      expect(uri.path).to eq('/nigiri')
    end

    it 'does not use connection params' do
      conn.url_prefix = 'http://sushi.com/nigiri'
      conn.params = { :a => 1 }
      expect(conn.build_exclusive_url.to_s).to eq('http://sushi.com/nigiri')
    end

    it 'allows to provide params argument' do
      conn.url_prefix = 'http://sushi.com/nigiri'
      conn.params = { :a => 1 }
      params = Faraday::Utils::ParamsHash.new
      params[:a] = 2
      uri = conn.build_exclusive_url(nil, params)
      expect(uri.to_s).to eq('http://sushi.com/nigiri?a=2')
    end

    it 'handles uri instances' do
      uri = conn.build_exclusive_url(URI('/sake.html'))
      expect(uri.path).to eq('/sake.html')
    end

    context 'with url_prefixed connection' do
      let(:url) { 'http://sushi.com/sushi/' }

      it 'parses url and changes scheme' do
        conn.scheme = 'https'
        uri = conn.build_exclusive_url('sake.html')
        expect(uri.to_s).to eq('https://sushi.com/sushi/sake.html')
      end

      it 'joins url to base with ending slash' do
        uri = conn.build_exclusive_url('sake.html')
        expect(uri.to_s).to eq('http://sushi.com/sushi/sake.html')
      end

      it 'used default base with ending slash' do
        uri = conn.build_exclusive_url
        expect(uri.to_s).to eq('http://sushi.com/sushi/')
      end

      it 'overrides base' do
        uri = conn.build_exclusive_url('/sake/')
        expect(uri.to_s).to eq('http://sushi.com/sake/')
      end
    end
  end

  describe '#build_url' do
    let(:url) { 'http://sushi.com/nigiri' }

    it 'uses params' do
      conn.params = { a: 1, b: 1 }
      expect(conn.build_url.to_s).to eq('http://sushi.com/nigiri?a=1&b=1')
    end

    it 'merges params' do
      conn.params = { a: 1, b: 1 }
      url = conn.build_url(nil, b: 2, c: 3)
      expect(url.to_s).to eq('http://sushi.com/nigiri?a=1&b=2&c=3')
    end
  end

  describe '#to_env' do
    subject { conn.build_request(:get).to_env(conn).url }

    let(:url) { 'http://sushi.com/sake.html' }
    let(:options) { { params: @params } }

    it 'parses url params into query' do
      @params = { 'a[b]' => '1 + 2' }
      expect(subject.query).to eq('a%5Bb%5D=1+%2B+2')
    end

    it 'escapes per spec' do
      @params = { 'a' => '1+2 foo~bar.-baz' }
      expect(subject.query).to eq('a=1%2B2+foo~bar.-baz')
    end

    it 'bracketizes nested params in query' do
      @params = { 'a' => { 'b' => 'c' } }
      expect(subject.query).to eq('a%5Bb%5D=c')
    end

    it 'bracketizes repeated params in query' do
      @params = { 'a' => [1, 2] }
      expect(subject.query).to eq('a%5B%5D=1&a%5B%5D=2')
    end

    it 'without braketizing repeated params in query' do
      @params = { 'a' => [1, 2] }
      conn.options.params_encoder = Faraday::FlatParamsEncoder
      expect(subject.query).to eq('a=1&a=2')
    end
  end

  describe 'proxy support' do
    it 'accepts string' do
      with_env 'http_proxy' => 'http://proxy.com:80' do
        conn.proxy = 'http://proxy.com'
        expect(conn.proxy.host).to eq('proxy.com')
      end
    end

    it 'accepts uri' do
      with_env 'http_proxy' => 'http://proxy.com:80' do
        conn.proxy = URI.parse('http://proxy.com')
        expect(conn.proxy.host).to eq('proxy.com')
      end
    end

    it 'accepts hash with string uri' do
      with_env 'http_proxy' => 'http://proxy.com:80' do
        conn.proxy = { :uri => 'http://proxy.com', :user => 'rick' }
        expect(conn.proxy.host).to eq('proxy.com')
        expect(conn.proxy.user).to eq('rick')
      end
    end

    it 'accepts hash' do
      with_env 'http_proxy' => 'http://proxy.com:80' do
        conn.proxy = { :uri => URI.parse('http://proxy.com'), :user => 'rick' }
        expect(conn.proxy.host).to eq('proxy.com')
        expect(conn.proxy.user).to eq('rick')
      end
    end

    it 'accepts http env' do
      with_env 'http_proxy' => 'http://proxy.com:80' do
        expect(conn.proxy.host).to eq('proxy.com')
      end
    end

    it 'accepts http env with auth' do
      with_env 'http_proxy' => 'http://a%40b:my%20pass@proxy.com:80' do
        expect(conn.proxy.user).to eq('a@b')
        expect(conn.proxy.password).to eq('my pass')
      end
    end

    it 'accepts env without scheme' do
      with_env 'http_proxy' => 'localhost:8888' do
        uri = conn.proxy[:uri]
        expect(uri.host).to eq('localhost')
        expect(uri.port).to eq(8888)
      end
    end

    it 'fetches no proxy from nil env' do
      with_env 'http_proxy' => nil do
        expect(conn.proxy).to be_nil
      end
    end

    it 'fetches no proxy from blank env' do
      with_env 'http_proxy' => '' do
        expect(conn.proxy).to be_nil
      end
    end

    it 'does not accept uppercase env' do
      with_env 'HTTP_PROXY' => 'http://localhost:8888/' do
        expect(conn.proxy).to be_nil
      end
    end

    it 'allows when url in no proxy list' do
      with_env 'http_proxy' => 'http://proxy.com', 'no_proxy' => 'example.com' do
        conn = Faraday::Connection.new('http://example.com')
        expect(conn.proxy).to be_nil
      end
    end

    it 'allows when prefixed url is not in no proxy list' do
      with_env 'http_proxy' => 'http://proxy.com', 'no_proxy' => 'example.com' do
        conn = Faraday::Connection.new('http://prefixedexample.com')
        expect(conn.proxy.host).to eq('proxy.com')
      end
    end

    it 'allows when subdomain url is in no proxy list' do
      with_env 'http_proxy' => 'http://proxy.com', 'no_proxy' => 'example.com' do
        conn = Faraday::Connection.new('http://subdomain.example.com')
        expect(conn.proxy).to be_nil
      end
    end

    it 'allows when url not in no proxy list' do
      with_env 'http_proxy' => 'http://proxy.com', 'no_proxy' => 'example2.com' do
        conn = Faraday::Connection.new('http://example.com')
        expect(conn.proxy.host).to eq('proxy.com')
      end
    end

    it 'allows when ip address is not in no proxy list but url is' do
      with_env 'http_proxy' => 'http://proxy.com', 'no_proxy' => 'localhost' do
        conn = Faraday::Connection.new('http://127.0.0.1')
        expect(conn.proxy).to be_nil
      end
    end

    it 'allows when url is not in no proxy list but ip address is' do
      with_env 'http_proxy' => 'http://proxy.com', 'no_proxy' => '127.0.0.1' do
        conn = Faraday::Connection.new('http://localhost')
        expect(conn.proxy).to be_nil
      end
    end

    it 'allows in multi element no proxy list' do
      with_env 'http_proxy' => 'http://proxy.com', 'no_proxy' => 'example0.com,example.com,example1.com' do
        expect(Faraday::Connection.new('http://example0.com').proxy).to be_nil
        expect(Faraday::Connection.new('http://example.com').proxy).to be_nil
        expect(Faraday::Connection.new('http://example1.com').proxy).to be_nil
        expect(Faraday::Connection.new('http://example2.com').proxy.host).to eq('proxy.com')
      end
    end

    it 'test proxy requires uri' do
      expect { conn.proxy = { uri: :bad_uri, user: 'rick' } }.to raise_error(ArgumentError)
    end

    it 'gives priority to manually set proxy' do
      with_env 'http_proxy' => 'http://proxy.com', 'no_proxy' => 'google.co.uk' do
        conn = Faraday.new
        conn.proxy = 'http://proxy2.com'

        expect(conn.instance_variable_get('@manual_proxy')).to be_truthy
        expect(conn.proxy_for_request('https://google.co.uk').host).to eq('proxy2.com')
      end
    end

    context 'performing a request' do
      before { stub_request(:get, 'http://example.com') }

      it 'dynamically checks proxy' do
        with_env 'http_proxy' => 'http://proxy.com:80' do
          conn = Faraday.new
          conn.get('http://example.com')
          expect(conn.instance_variable_get('@temp_proxy').host).to eq('proxy.com')
        end

        conn.get('http://example.com')
        expect(conn.instance_variable_get('@temp_proxy')).to be_nil
      end

      it 'dynamically check no proxy' do
        with_env 'http_proxy' => 'http://proxy.com', 'no_proxy' => 'example.com' do
          conn = Faraday.new

          expect(conn.instance_variable_get('@temp_proxy').host).to eq('proxy.com')
          conn.get('http://example.com')
          expect(conn.instance_variable_get('@temp_proxy')).to be_nil
        end
      end
    end
  end
end