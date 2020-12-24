% Copyright (c) 2008 Andrew Collette and contributors
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
% 
% 1. Redistributions of source code must retain the above copyright
%    notice, this list of conditions and the following disclaimer.
% 
% 2. Redistributions in binary form must reproduce the above copyright
%    notice, this list of conditions and the following disclaimer in the
%    documentation and/or other materials provided with the
%    distribution.
% 
% 3. Neither the name of the copyright holder nor the names of its
%    contributors may be used to endorse or promote products derived from
%    this software without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
% A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
% HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
% LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
% DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
% THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
% (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


function chunks = guessChunkSize(dataType, maxSize)
%GUESSCHUNKSIZE Derives a normal chunk size based on the dataset's maximum size
% the implementation is adapted from h5py's method.
assert(~isempty(maxSize) && isnumeric(maxSize) && all(maxSize > 0),...
    'NWB:Types:Untyped:DataPipe:guessChunkSize:InvalidArgument',...
    'Max Size cannot be empty and must be a natural number.');

chunkBase = 16 * 1024;
chunkMin = 8 * 1024;
chunkMax = 1024 * 1024;

maxSize(isinf(maxSize)) = 1024;
typeSize = io.getMatTypeSize(dataType);

chunks = maxSize;
totalByteSize = prod(chunks) * typeSize;
targetByteSize = chunkBase * pow2(log10(totalByteSize / chunkMax));
targetByteSize = min([chunkMax, targetByteSize]);
targetByteSize = max([chunkMin, targetByteSize]);

while true
    for ind = 1:length(chunks)
        chunkNumElem = prod(chunks);
        if 1 == chunkNumElem
            return;
        end
        
        chunkByteSize = chunkNumElem * typeSize;
        if (chunkByteSize < targetByteSize || chunkByteSize < chunkMax)...
                && abs(chunkByteSize - targetByteSize) / targetByteSize < 0.5
            return;
        end
        
        chunks(ind) = ceil(chunks(ind) / 2);
    end
end
end

