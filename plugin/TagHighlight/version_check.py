try:
    import import_check
    import sys
    if sys.hexversion < 0x02060000:
        raise ValueError("Incorrect python version")
    operational = True
except:
    operational = False

if operational:
    sys.stdout.write("OK\nVERSION:%s\n" % sys.version)
else:
    # May not have imported sys
    import sys
    sys.stdout.write("NOT OK\nVERSION:%s\n" % sys.version)
