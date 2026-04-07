#!/bin/bash
set +m
trap 'kill ${PIDS[@]} 2>/dev/null' EXIT INT TERM
PIDS=()
dns-sd -R "Zebra_DHL @ Tims-MacBook-Pro" "_ipp._tcp.,_universal" "local" 631 "txtvers=1" "qtotal=1" "rp=printers/Zebra_DHL" "ty=Zebra ZPL Label Printer" "product=(Zebra ZPL Label Printer)" "note= via Tims-MacBook-Pro" "pdl=application/pdf,image/jpeg,image/urf" "URF=V1.4,MS_CUSTOM_100x150mm" "Color=F" "Duplex=F"  &
PIDS+=("$!")
wait
