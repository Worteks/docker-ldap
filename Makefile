SKIP_SQUASH?=1

ifeq ($(TARGET),rhel7)
	OS := rhel7
else
	OS := centos7
endif

.PHONY: build
build:
	@@SKIP_SQUASH=$(SKIP_SQUASH) hack/build.sh $(OS)

.PHONY: test
test:
	@@SKIP_SQUASH=$(SKIP_SQUASH) TAG_ON_SUCCESS=$(TAG_ON_SUCCESS) TEST_MODE=true hack/build.sh $(OS)

.PHONY: run
run:
	@@docker run wsweet/openldap

.PHONY: debug
debug:
	@@MAINDEV=`ip r | awk '/default/' | sed 's|.* dev \([^ ]*\).*|\1|'`; \
	MAINIP=`ip r | awk "/ dev $$MAINDEV .* src /" | sed 's|.* src \([^ ]*\).*$$|\1|'`; \
	docker run -e OPENLDAP_HOST_ENDPOINT=$$MAINIP \
	    -e OPENLDAP_DEMO_PASSWORD=secret \
	    -e OPENLDAP_DEBUG=yesplease \
	    -p 389:389 -p 636:636 wsweet/openldap

.PHONY: demo
demo:
	@@MAINDEV=`ip r | awk '/default/' | sed 's|.* dev \([^ ]*\).*|\1|'`; \
	MAINIP=`ip r | awk "/ dev $$MAINDEV .* src /" | sed 's|.* src \([^ ]*\).*$$|\1|'`; \
	docker run -e OPENLDAP_HOST_ENDPOINT=$$MAINIP \
	    -e OPENLDAP_DEMO_PASSWORD=secret \
	    -p 389:389 -p 636:636 wsweet/openldap

.PHONY: prod
prod:
	@@MAINDEV=`ip r | awk '/default/' | sed 's|.* dev \([^ ]*\).*|\1|'`; \
	MAINIP=`ip r | awk "/ dev $$MAINDEV .* src /" | sed 's|.* src \([^ ]*\).*$$|\1|'`; \
	docker run -e OPENLDAP_HOST_ENDPOINT=$$MAINIP \
	    -e OPENLDAP_GLOBAL_ADMIN_PASSWORD=secret \
	    -p 389:389 -p 636:636 wsweet/openldap

.PHONY: ocbuild
ocbuild: occheck
	oc process -f openshift/imagestream.yaml -p FRONTNAME=wsweet | oc apply -f-
	BRANCH=`git rev-parse --abbrev-ref HEAD`; \
	if test "$$GIT_DEPLOYMENT_TOKEN"; then \
	    oc process -f openshift/build-with-secret.yaml \
		-p "FRONTNAME=wsweet" \
		-p "GIT_DEPLOYMENT_TOKEN=$$GIT_DEPLOYMENT_TOKEN" \
		-p "LDAP_REPOSITORY_REF=$$BRANCH" \
		| oc apply -f-; \
	else \
	    oc process -f openshift/build.yaml \
		-p "FRONTNAME=wsweet" \
		-p "LDAP_REPOSITORY_REF=$$BRANCH" \
		| oc apply -f-; \
	fi

.PHONY: occheck
occheck:
	oc whoami >/dev/null 2>&1 || exit 42

.PHONY: occlean
occlean: occheck
	oc process -f openshift/run-ha.yaml -p FRONTNAME=wsweet | oc delete -f- || true
	oc process -f openshift/run-persistent.yaml -p FRONTNAME=wsweet | oc delete -f- || true
	oc process -f openshift/secret.yaml -p FRONTNAME=wsweet | oc delete -f- || true

.PHONY: ocdemoephemeral
ocdemoephemeral: ocbuild
	if ! oc describe secret openldap-wsweet >/dev/null 2>&1; then \
	    oc process -f openshift/secret.yaml -p FRONTNAME=wsweet | oc apply -f-; \
	fi
	oc process -f openshift/run-ephemeral.yaml -p FRONTNAME=wsweet | oc apply -f-

.PHONY: ocdemopersistent
ocdemopersistent: ocbuild
	if ! oc describe secret openldap-wsweet >/dev/null 2>&1; then \
	    oc process -f openshift/secret.yaml -p FRONTNAME=wsweet | oc apply -f-; \
	fi
	oc process -f openshift/run-persistent.yaml -p FRONTNAME=wsweet | oc apply -f-

.PHONY: ocdemo
ocdemo: ocdemoephemeral

.PHONY: ocprod
ocprod: ocbuild
	if ! oc describe secret openldap-wsweet >/dev/null 2>&1; then \
	    oc process -f openshift/secret-prod.yaml -p FRONTNAME=wsweet | oc apply -f-; \
	fi
	oc process -f openshift/run-ha.yaml -p FRONTNAME=wsweet | oc apply -f-

.PHONY: ocpurge
ocpurge: occlean
	oc process -f openshift/build.yaml -p FRONTNAME=wsweet | oc delete -f- || true
	oc process -f openshift/imagestream.yaml -p FRONTNAME=wsweet | oc delete -f- || true
