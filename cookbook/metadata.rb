name             'online-ruby-tutor-cookbook'
maintainer       'Daniel Stutzman'
maintainer_email 'dtstutz@gmail.com'
license          'All rights reserved'
description      'Installs/Configures online-ruby-tutor'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

depends 'apt', '~> 2.3.4'
#depends 'postgresql'
depends 'postgresql', '~> 3.2.0' # 3.2.0 to fix https://github.com/hw-cookbooks/postgresql/issues/94
depends 'database'
