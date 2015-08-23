#!/bin/bash

if [ -z $PREFIX ]; then
	echo 
	echo "Please specify a path to install to:"
	read tools
else
        tools=$PREFIX
fi

# Logging
date_str="+%Y_%m%d_%H%M%S"
full_date=`date $date_str`
host=$(hostname)
log="output_"$host"_"$full_date.log

exec > >(tee --append $log)
exec 2>&1


# Main install

mkdir -p $tools
case "$tools" in
	/*)
	;;
	*)
	tools=$(pwd)/$tools
	;;
esac

echo "Installing in: "$tools

if [ -z $GDAL_VERSION ]; then
	default="1.10.0"
	echo -e "Choose GDAL version ($default): \c"
	read gdal_version
	[ -z "$gdal_version" ] && gdal_version=$default
else
        gdal_version=$GDAL_VERSION
fi

echo "Using: gdal $gdal_version"
  
if [ -z $FILEGDB_API_PATH ]; then
	echo "If you need FileGDB write support, download and extract the API from ESRI"
	echo "http://www.esri.com/apps/products/download/#File_Geodatabase_API_1.4"
	echo -e "Path to extracted FileGDB_API (no support): \c"
	read -e filegdb_api_path 
else
	filegdb_api_path=$FILEGDB_API_PATH
fi

if [ -n "$filegdb_api_path" -a -d "$filegdb_api_path" ]; then
    	echo "Using:  $filegdb_api_path"
    filegdb_flags="--with-fgdb=$filegdb_api_path"
    filegdb_ldpath="$filegdb_api_path/lib:"
else
    echo "No path specified or path is invalid, FileGDB support will not be included"
    filegdb_flags=""
    filegdb_ldpath=""
fi

export	PATH=$tools/anaconda/bin:$tools/gdal/bin:$PATH
export	LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$tools/gdal/lib:$tools/openjpeg-2/lib:$tools/proj/lib

# Install MiniConda Python distribution
# This will build the base directory /tools for all following software

cd $tools && \
wget --no-check-certificate -nv \
http://repo.continuum.io/miniconda/Miniconda-3.7.0-Linux-x86_64.sh && \
bash Miniconda-3.7.0-Linux-x86_64.sh -b -p $tools/anaconda && \
rm -f Miniconda*
echo y | conda install scipy jinja2 conda-build dateutil

# Install conda postgresql client package
vers=0.1
cd $tools && \
wget --no-check-certificate -nv \
https://github.com/minadyn/conda-postgresql-client/archive/$vers.zip && \
unzip $vers && \
conda build conda-postgresql-client-$vers && \
conda install --yes $(conda build conda-postgresql-client-$vers --output) && \
rm -f conda-postgresql-client-$vers

# Install CFITSIO
cd $tools && \
wget --no-check-certificate -nv \
https://github.com/PolarGeospatialCenter/asp/raw/master/originals/cfitsio/cfitsio3360.tar.gz && \
tar xvfz cfitsio3360.tar.gz && \
cd cfitsio && \
./configure --prefix=$tools/cfitsio --enable-sse2 --enable-ssse3 --enable-reentrant && \
make -j && make install

# GEOS
export	SWIG_FEATURES="-I/usr/share/swig/1.3.40/python -I/usr/share/swig/1.3.40"
cd $tools && \
wget --no-check-certificate -nv \
https://github.com/PolarGeospatialCenter/asp/raw/master/originals/geos/geos-3.4.2.tar.bz2 && \
tar xvfj geos-3.4.2.tar.bz2 && \
cd geos-3.4.2 && \
./configure --prefix=$tools/geos && \
make -j && make install 

# PROJ
cd $tools && \
wget --no-check-certificate -nv \
https://github.com/PolarGeospatialCenter/asp/raw/master/originals/proj/proj-4.8.0.tar.gz && \
tar xvfz proj-4.8.0.tar.gz && \
cd proj-4.8.0 && \
./configure --prefix=$tools/proj --with-jni=no && \
make -j && make install

# Cmake 3.4.1
cd $tools &&
wget https://cmake.org/files/v3.4/cmake-3.4.1.tar.gz --nv && \
tar xvfz cmake-3.4.1.tar.gz && \
cd cmake-3.4.1 && \
./configure && \
make

# OPENJPEG
# Change to cmake or cmake28 depending on what is installed
cd $tools && \
wget --no-check-certificate -nv \
https://github.com/PolarGeospatialCenter/asp/raw/master/originals/openjpeg/openjpeg-2.0.0.tar.gz && \
tar xvfz openjpeg-2.0.0.tar.gz && \
cd openjpeg-2.0.0 && \
$tools/cmake-2.8.12.2/bin/cmake -DCMAKE_INSTALL_PREFIX=$tools/openjpeg-2 && \
make install

# GDAL
# Parallel make will fail due to race conditions. Do not use -j
# GDAL 1.11 breaks sparse_disp
export	SWIG_FEATURES="-I/usr/share/swig/1.3.40/python -I/usr/share/swig/1.3.40"

cd $tools && \
wget --no-check-certificate -nv \
http://download.osgeo.org/gdal/$gdal_version/gdal-$gdal_version.tar.gz && \
tar xvfz gdal-$gdal_version.tar.gz && \
cd gdal-$gdal_version && \
./configure --prefix=$tools/gdal --with-geos=$tools/geos/bin/geos-config --with-cfitsio=$tools/cfitsio \
--with-python --with-openjpeg=$tools/openjpeg-2 --with-sqlite3=no \
$filegdb_flags && \
make && make install && \
cd swig/python && python setup.py install

export	GDAL_DATA=$tools/gdal/share/gdal

echo "export	PATH=$tools/anaconda/bin:$tools/gdal/bin:\$PATH" >> $tools/init-gdal.sh
echo "export	GDAL_DATA=$tools/gdal/share/gdal" >> $tools/init-gdal.sh
echo "export	LD_LIBRARY_PATH=$tools/gdal/lib:$tools/openjpeg-2/lib:$tools/proj/lib:$filegdb_ldpath\$LD_LIBRARY_PATH" >> $tools/init-gdal.sh
chmod a+x $tools/init-gdal.sh
echo
echo	"The tools were installed in $tools."
echo	"There is an init script that sets the environment and is installed at $tools/init-gdal.sh. You can source this file to run."
