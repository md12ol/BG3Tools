#!/bin/sh
# w2s.sh X Y Z: project a world point to frame (1389x868) pixels with the camera matrices the client probe writes.
D="$LOCALAPPDATA/Larian Studios/Baldur's Gate 3/Script Extender"
awk -v x=$1 -v y=$2 -v z=$3 '
  /^cam/ { split($3, a, "[=x]"); W=a[2]; H=a[3] }
  /^V / { for(i=2;i<=17;i++) V[i-1]=$i }
  /^P / { for(i=2;i<=17;i++) P[i-1]=$i }
  END { v[1]=x; v[2]=y; v[3]=z; v[4]=1
    for(i=1;i<=4;i++) t[i]=V[i]*v[1]+V[4+i]*v[2]+V[8+i]*v[3]+V[12+i]*v[4]
    for(i=1;i<=4;i++) c[i]=P[i]*t[1]+P[4+i]*t[2]+P[8+i]*t[3]+P[12+i]*t[4]
    if (c[4]<=0) { print "behind"; exit }
    sx=(c[1]/c[4]+1)/2*W; sy=(1-c[2]/c[4])/2*H
    printf "%d %d\n", sx*1389/W, sy*868/H }' "$D/BuildAdvisor_client.txt"
