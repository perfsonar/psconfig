#!/usr/bin/env python3

from setuptools import setup
setup(
    name='psconfig',
    version='5.0.0',
    description='pSConfig',
    url='http://www.perfsonar.net',
    author='The perfSONAR Development Team',
    author_email='perfsonar-developer@perfsonar.net',
    license='Apache 2.0',
    packages=[
        'psconfig',
        'psconfig.lib',
        'psconfig.lib.pscheduler',
        'psconfig.lib.psconfig',
        'psconfig.lib.shared',
        'psconfig.lib.shared.client',
        'psconfig.lib.shared.client.pscheduler',
        'psconfig.lib.shared.client.psconfig',
        'psconfig.lib.shared.client.psconfig.translators',
        'psconfig.lib.shared.client.psconfig.translators.mesh_config',
        'psconfig.lib.shared.client.psconfig.parsers',
        'psconfig.lib.shared.client.psconfig.address_classes',
        'psconfig.lib.shared.client.psconfig.address_classes.filters',
        'psconfig.lib.shared.client.psconfig.address_classes.data_sources',
        'psconfig.lib.shared.client.psconfig.groups',
        'psconfig.lib.shared.client.psconfig.addresses',
        'psconfig.lib.shared.client.psconfig.address_selectors',
        'psconfig.lib.shared.utilities'
    ],
    install_requires=[
        'requests',
        'jsonschema',
        'pyjq',
        'isodate'
    ],
    include_package_data=True,
    package_data={},

    tests_require=['nose'],
    test_suite='nose.collector',
)
