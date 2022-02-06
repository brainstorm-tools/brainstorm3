function [sndx,ssize,nslices] = sll_sliceblocks(n,slicesize)

nslices = ceil(n/slicesize);

for s = 1:nslices-1
    sndx{s} = (s-1)*slicesize+1 : slicesize*s;
    ssize(s) = slicesize;
end
sndx{nslices}=(nslices-1)*slicesize+1:n;
ssize(nslices) = length(sndx{nslices});