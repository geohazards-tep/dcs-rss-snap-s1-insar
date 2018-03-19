#!/usr/bin/python
import sys

x_min=float(sys.argv[1])
x_max=float(sys.argv[2])
y_min=float(sys.argv[3])
y_max=float(sys.argv[4])

a = y_min/x_min + y_max/(x_max-x_min) - y_min*(x_max/x_min)/(x_max-x_min)
b = (y_min*x_max-y_max*x_min)/(x_max-x_min)

print "a=", a
print "b=", b