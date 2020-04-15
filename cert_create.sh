#!/usr/bin/env bash

read -p "Would you like to configure TLS encryption now [y/N]? " -i n
if [[ ! $REPLY =~ ^[Yy].*$ ]]; then
 exit
fi

while [ ! "$CERT_PATH" ]; do read -ep "Enter the path where certs and keys will be stored: " CERT_PATH; done
if [ ! -d $CERT_PATH ]; then echo Directory $CERT_PATH invalid. Please create and re-run this script.; exit; fi

UNIQUE=($(date|md5sum))

openssl genrsa -out $CERT_PATH/ca-key_$UNIQUE.pem 2048
if [ $? != 0 ]; then
 echo Failed to generate CA key, exiting...
 exit 1
fi
echo "CA key successfully created at $CERT_PATH/ca-key_$UNIQUE.pem"

echo "+-----------------------------------------------------+"
echo "| Fields are optional unless prefixed with (REQUIRED) |"
echo "+-----------------------------------------------------+"
read -ep "Two-letter country code (eg, US): " OPENSSL_C
read -ep "Full state or province name (eg, Wisconsin): " OPENSSL_ST
read -ep "City/locality name (eg, Milwaukee): " OPENSSL_L
read -ep "Organization name (eg, My ISP, LLC): " OPENSSL_O
read -ep "Organizational unit name (eg, Department of Redundancy Department): " OPENSSL_OU
while [ ! "$OPENSSL_CA" ]; do read -ep "(REQUIRED) Common Name for your Certificate Authority (eg, My ISP CA): " OPENSSL_CA; done
while [ ! "$OPENSSL_CN" ]; do read -ep "(REQUIRED) Common Name for your server certificate (eg, $(hostname -f)): " OPENSSL_CN; done
[ "$OPENSSL_C" ]  && OPENSSL_SUBJECT="$OPENSSL_SUBJECT/C=$OPENSSL_C"
[ "$OPENSSL_ST" ] && OPENSSL_SUBJECT="$OPENSSL_SUBJECT/ST=$OPENSSL_ST"
[ "$OPENSSL_L"  ] && OPENSSL_SUBJECT="$OPENSSL_SUBJECT/L=$OPENSSL_L"
[ "$OPENSSL_O"  ] && OPENSSL_SUBJECT="$OPENSSL_SUBJECT/O=$OPENSSL_O"
[ "$OPENSSL_OU" ] && OPENSSL_SUBJECT="$OPENSSL_SUBJECT/OU=$OPENSSL_OU"
[ "$OPENSSL_CA" ] && OPENSSL_SUBJECT_CA="$OPENSSL_SUBJECT/CN=$OPENSSL_CA"
[ "$OPENSSL_CN" ] && OPENSSL_SUBJECT_SRV="$OPENSSL_SUBJECT/CN=$OPENSSL_CN"
[ "$OPENSSL_CN" ] && OPENSSL_SUBJECT_CLIENT="$OPENSSL_SUBJECT/CN=Sonar"

echo Creating CA server certificate...
openssl req -sha256 -new -x509 -nodes -days 10000 -subj "$OPENSSL_SUBJECT_CA" \
  -key $CERT_PATH/ca-key_$UNIQUE.pem -out $CERT_PATH/ca-cert_$UNIQUE.pem
if [ $? != 0 ]; then echo Failed to create CA cert, exiting...; exit 1; fi

echo Creating TLS server certificate request...
openssl req -sha256 -newkey rsa:2048 -nodes -subj "$OPENSSL_SUBJECT_CA" \
  -keyout $CERT_PATH/server-key.pem -out $CERT_PATH/server-req.pem
if [ $? != 0 ]; then echo Failed to create TLS server request, exiting...; exit 1; fi

echo Signing TLS server certificate request with CA certificate...
openssl x509 -sha256 -req -in $CERT_PATH/server-req.pem -days 10000 -CA $CERT_PATH/ca-cert_$UNIQUE.pem \
  -CAkey $CERT_PATH/ca-key_$UNIQUE.pem -set_serial 01 -out $CERT_PATH/server-cert.pem
if [ $? != 0 ]; then echo Failed to sign TLS server request, exiting...; exit 1; fi

echo Creating TLS client certificate request...
openssl req -sha256 -newkey rsa:2048 -nodes -subj "$OPENSSL_SUBJECT_CLIENT" \
  -keyout $CERT_PATH/client-key.pem -out $CERT_PATH/client-req.pem
if [ $? != 0 ]; then echo Failed to create TLS client request, exiting...; exit 1; fi

echo Signing TLS client certificate request with CA certificate...
openssl x509 -sha256 -req -in $CERT_PATH/client-req.pem -days 10000 -CA $CERT_PATH/ca-cert_$UNIQUE.pem \
  -CAkey $CERT_PATH/ca-key_$UNIQUE.pem -set_serial 01 -out $CERT_PATH/client-cert.pem
if [ $? != 0 ]; then echo Failed to sign TLS client request, exiting...; exit 1; fi
