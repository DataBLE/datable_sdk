Pod::Spec.new do |s|

    s.name              = 'SRBeacon'
    s.version           = '0.3.7'
    s.summary           = 'iBeacon SDK by SkuRun'
    s.homepage          = 'https://protected-springs-5667.herokuapp.com/admin/'
    s.license           = {
        :type => 'MIT',
        :file => 'LICENSE'
    }
    s.author            = {
        'Zheng Huiying' => 'xinliang1111@gmail.com'
    }
    s.source            = {
        :git => 'https://github.com/SkuRun/SRBeacon.git',
        :tag => '0.3.7'
    }
    s.platform          = :ios, '7.0'
    s.source_files      = 'SRBeacon/SRBeacon/*.{m,h}'
    s.requires_arc      = true
    s.dependency 'AFNetworking', '~> 2.1.0'
    s.dependency 'Reachability', '~> 3.1.1'
end
