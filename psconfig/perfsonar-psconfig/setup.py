#!/usr/bin/python3

from setuptools import setup, find_packages
setup(
    name='psconfig',
    version='5.1.0',
    description='pSConfig',
    url='http://www.perfsonar.net',
    author='The perfSONAR Development Team',
    author_email='perfsonar-developer@perfsonar.net',
    license='Apache 2.0',
    packages=find_packages('src'),
    package_dir={'': 'src'},
    install_requires=['requests',
                      'python-dateutil==2.8.2',
                      'inotify'],
    include_package_data=True,
    package_data={},

    tests_require=['nose'],
    test_suite='nose.collector',
)
