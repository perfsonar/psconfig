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
    packages=[
        'psconfig',
        'psconfig.client',
        'psconfig.client.pscheduler',
        'psconfig.client.psconfig',
        'psconfig.client.psconfig.address_classes',
        'psconfig.client.psconfig.address_classes.filters',
        'psconfig.client.psconfig.address_classes.data_sources',
        'psconfig.client.psconfig.address_selectors',
        'psconfig.client.psconfig.addresses',
        'psconfig.client.psconfig.groups',
        'psconfig.client.psconfig.parsers',
        'psconfig.client.psconfig.translators',
        'psconfig.client.psconfig.translators.mesh_config',
        'psconfig.pscheduler',
        'psconfig.utilities'
    ],
    install_requires=['requests',
                      'jsonschema',
                      'pyjq',
                      'isodate'
                      'python-dateutil==2.8.2',
                      'pyinotify'],
    include_package_data=True,
    package_data={},

    tests_require=['nose'],
    test_suite='nose.collector',
)
