#!/bin/bash

echo
echo "Please specify a path to install to:"
read tools

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

default="2.1.3"
echo -e "Choose GDAL version ($default): \c"
read gdal_version
[ -z "$gdal_version" ] && gdal_version=$default
echo "Using: gdal $gdal_version"

echo "If you need FileGDB write support, download and extract the API from ESRI"
echo "http://www.esri.com/apps/products/download/#File_Geodatabase_API_1.4"
echo -e "Path to extracted FileGDB_API (no support): \c"
read -e filegdb_api_path
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
export	LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$tools/gdal/lib:$tools/openjpeg-2/lib:$tools/proj/lib:$tools/anaconda/lib:$tools/pgsql/lib

# Install MiniConda Python distribution
# This will build the base directory /tools for all following software

cd $tools && \
wget --no-check-certificate \
http://repo.continuum.io/miniconda/Miniconda2-4.7.10-Linux-x86_64.sh && \
bash Miniconda2-4.7.10-Linux-x86_64.sh -b -p $tools/anaconda && \
rm -f Miniconda*
echo y | conda install scipy jinja2 conda-build shapely scikit-image pandas lxml openssl zlib readline
echo y | conda install -c conda-forge -c anaconda scandir python-dateutil

# Install configargparse package
cd $tools && \
wget --no-check-certificate \
https://github.com/bw2/ConfigArgParse/archive/master.zip && \
unzip master.zip && \
cd ConfigArgParse-master && \
python setup.py build && \
python setup.py install && \
cd .. && \
rm -f master.zip

# Install postgresql client
cd $tools && \
wget --no-check-certificate https://ftp.postgresql.org/pub/source/v9.5.22/postgresql-9.5.22.tar.gz && \
tar xvzf postgresql-9.5.22.tar.gz && \
cd postgresql-9.5.22 && \
./configure --prefix=$tools/pgsql --with-openssl --with-libraries=$tools/anaconda/lib --with-includes=$tools/anaconda/include && \
make && \
make -C src/bin install && \
make -C src/include install && \
make -C src/interfaces install && \
make -C doc install && \
rm -f postgresql-9.5.22.tar.gz

# Install CFITSIO
cd $tools && \
wget --no-check-certificate \
https://github.com/PolarGeospatialCenter/asp/raw/master/originals/cfitsio/cfitsio3360.tar.gz && \
tar xvfz cfitsio3360.tar.gz && \
cd cfitsio && \
./configure --prefix=$tools/cfitsio --enable-sse2 --enable-ssse3 --enable-reentrant && \
make -j && make install

# GEOS
export	SWIG_FEATURES="-I/usr/share/swig/1.3.40/python -I/usr/share/swig/1.3.40"
cd $tools && \
wget --no-check-certificate \
https://github.com/PolarGeospatialCenter/asp/raw/master/originals/geos/geos-3.4.2.tar.bz2 && \
tar xvfj geos-3.4.2.tar.bz2 && \
cd geos-3.4.2 && \
./configure --prefix=$tools/geos && \
make -j && make install

# PROJ
cd $tools && \
wget --no-check-certificate \
https://github.com/PolarGeospatialCenter/asp/raw/master/originals/proj/proj-4.9.3.tar.gz && \
tar xvfz proj-4.9.3.tar.gz && \
cd proj-4.9.3 && \
./configure --prefix=$tools/proj --with-jni=no && \
make -j && make install

# Cmake 3.4.1
cd $tools &&
wget --no-check-certificate https://cmake.org/files/v3.4/cmake-3.4.1.tar.gz && \
tar xvfz cmake-3.4.1.tar.gz && \
cd cmake-3.4.1 && \
./configure && \
gmake

# OPENJPEG
# Change to cmake or cmake28 depending on what is installed
cd $tools && \
wget --no-check-certificate \
https://github.com/PolarGeospatialCenter/asp/raw/master/originals/openjpeg/openjpeg-2.0.0.tar.gz && \
tar xvfz openjpeg-2.0.0.tar.gz && \
cd openjpeg-2.0.0 && \
$tools/cmake-3.4.1/bin/cmake -DCMAKE_INSTALL_PREFIX=$tools/openjpeg-2 && \
make install

#NetCDF
cd $tools && \
wget --no-check-certificate \
ftp://ftp.unidata.ucar.edu/pub/netcdf/netcdf-4.4.1.1.tar.gz && \
tar xvfz netcdf-4.4.1.1.tar.gz && \
cd netcdf-4.4.1.1 && \
./configure --prefix=$tools/netCDF --disable-netcdf-4 && \
make -j && make install

# GDAL
# Parallel make will fail due to race conditions. Do not use -j
# GDAL 1.11 breaks sparse_disp
export	SWIG_FEATURES="-I/usr/share/swig/1.3.40/python -I/usr/share/swig/1.3.40"

cd $tools && \
wget --no-check-certificate \
http://download.osgeo.org/gdal/$gdal_version/gdal-$gdal_version.tar.gz && \
tar xvfz gdal-$gdal_version.tar.gz && \
cd gdal-$gdal_version && \
./configure --prefix=$tools/gdal --with-geos=$tools/geos/bin/geos-config --with-cfitsio=$tools/cfitsio \
--with-python --with-openjpeg=$tools/openjpeg-2 --with-sqlite3=no --with-netcdf=$tools/netCDF --with-pg=$tools/pgsql/bin/pg_config \
$filegdb_flags && \
make && make install && \
cd swig/python && python setup.py install

export	GDAL_DATA=$tools/gdal/share/gdal

echo "export	PATH=$tools/anaconda/bin:$tools/gdal/bin:$tools/pgsql/bin:\$PATH" >> $tools/init-gdal.sh
echo "export	GDAL_DATA=$tools/gdal/share/gdal" >> $tools/init-gdal.sh
echo "export	LD_LIBRARY_PATH=$tools/gdal/lib:$tools/openjpeg-2/lib:$tools/proj/lib:$filegdb_ldpath:$tools/netCDF/lib:$tools/pgsql/lib:$tools/anaconda/lib:\$LD_LIBRARY_PATH" >> $tools/init-gdal.sh
echo
echo	"The tools were installed in $tools."
echo	"There is an init script that sets the environment and is installed at $tools/init-gdal.sh. You can source this file to run."
