#!/bin/bash
rm -rf /root/deploy/repodata/*
rm -rf /root/deploy/osdata/*
rm -rf /root/deploy/staging/*
rm -rf /root/deploy/packaged/*
ssh deploytest1 rm -rf /root/deploy
ssh deploytest2 rm -rf /root/deploy
