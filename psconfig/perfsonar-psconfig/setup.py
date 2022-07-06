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
    ],
    install_requires=[],
    include_package_data=True,
    package_data={},

    tests_require=['nose'],
    test_suite='nose.collector',
)
