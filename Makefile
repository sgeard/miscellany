.PHONY: all clean

all: lamb_w.apk lamb_w-apk-sha512
	@cp -uvf ../misc/{lamb_w.tcl,solver.tcl} .
	@git add $(git ls-files --modified --exclude-standard)

lamb_w.apk: /home/simon/awsdk/build/outputs/apk/debug/AndroWishApp-debug.apk
	@cp -uvf $< $@

lamb_w-apk-sha512: lamb_w.apk
	sha512sum $< > $@

clean:
	@rm -vf lamb_w.apk lamb_w-apk-sha512
