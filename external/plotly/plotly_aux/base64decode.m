function y = base64decode(x, outfname, alg)
%BASE64DECODE Perform base64 decoding on a string.
%
% INPUT:
%   x    - block of data to be decoded.  Can be a string or a numeric  
%          vector containing integers in the range 0-255. Any character
%          not part of the 65-character base64 subset set is silently
%          ignored.  Characters occuring after a '=' padding character are 
%          never decoded. If the length of the string to decode (after 
%          ignoring non-base64 chars) is not a multiple of 4, then a 
%          warning is generated.
%
%   outfname - if provided the binary date from decoded string will be
%          saved into a file. Since Base64 coding is often used to embbed
%          binary data in xml files, this option can be used to extract and
%          save them.
%
%   alg  - Algorithm to use: can take values 'java' or 'matlab'. Optional
%          variable defaulting to 'java' which is a little faster. If 
%          'java' is chosen than core of the code is performed by a call to
%          a java library. Optionally all operations can be performed using
%          matleb code. 
%
% OUTPUT:
%   y    - array of binary data returned as uint8 
%
%   This function is used to decode strings from the Base64 encoding specified
%   in RFC 2045 - MIME (Multipurpose Internet Mail Extensions).  The Base64
%   encoding is designed to represent arbitrary sequences of octets in a form
%   that need not be humanly readable.  A 65-character subset ([A-Za-z0-9+/=])
%   of US-ASCII is used, enabling 6 bits to be represented per printable
%   character.
%
%   See also BASE64ENCODE.
%
%   Written by Jarek Tuszynski, SAIC, jaroslaw.w.tuszynski_at_saic.com
%
%   Matlab version based on 2004 code by Peter J. Acklam
%   E-mail:      pjacklam@online.no
%   URL:         http://home.online.no/~pjacklam
%   http://home.online.no/~pjacklam/matlab/software/util/datautil/base64encode.m

if nargin<3, alg='java';  end
if nargin<2, outfname=''; end

%% if x happen to be a filename than read the file
if (numel(x)<256)
  if (exist(x, 'file')==2)
    fid = fopen(x,'rb');
    x = fread(fid, 'uint8');   
    fclose(fid);
  end
end
x = uint8(x(:)); % unify format

%% Perform conversion
switch (alg)
  case 'java' 
    base64 = org.apache.commons.codec.binary.Base64;
    y = base64.decode(x);
    y = mod(int16(y),256); % convert from int8 to uint8
  case 'matlab'
    %%  Perform the mapping
    %   A-Z  ->  0  - 25
    %   a-z  ->  26 - 51
    %   0-9  ->  52 - 61
    %   + -  ->  62       '-' is URL_SAFE alternative
    %   / _  ->  63       '_' is URL_SAFE alternative
    map = uint8(zeros(1,256)+65);
    map(uint8(['A':'Z', 'a':'z', '0':'9', '+/=']))= 0:64;
    map(uint8('-_'))= 62:63;  % URL_SAFE alternatives
    x = map(x);  % mapping
    
    x(x>64)=[]; % remove non-base64 chars
    if rem(numel(x), 4)
      warning('Length of base64 data not a multiple of 4; padding input.');
    end
    x(x==64)=[]; % remove padding characters
    
    %% add padding and reshape
    nebytes = length(x);         % number of encoded bytes
    nchunks = ceil(nebytes/4);   % number of chunks/groups
    if rem(nebytes, 4)>0
      x(end+1 : 4*nchunks) = 0;  % add padding
    end
    x = reshape(uint8(x), 4, nchunks);
    y = repmat(uint8(0), 3, nchunks);            % for the decoded data
    
    %% Rearrange every 4 bytes into 3 bytes
    %    00aaaaaa 00bbbbbb 00cccccc 00dddddd
    % to form
    %    aaaaaabb bbbbcccc ccdddddd
    y(1,:) = bitshift(x(1,:), 2);                 % 6 highest bits of y(1,:)
    y(1,:) = bitor(y(1,:), bitshift(x(2,:), -4)); % 2 lowest  bits of y(1,:)
    y(2,:) = bitshift(x(2,:), 4);                 % 4 highest bits of y(2,:)
    y(2,:) = bitor(y(2,:), bitshift(x(3,:), -2)); % 4 lowest  bits of y(2,:)
    y(3,:) = bitshift(x(3,:), 6);                 % 2 highest bits of y(3,:)
    y(3,:) = bitor(y(3,:), x(4,:));               % 6 lowest  bits of y(3,:)
    
    %% remove extra padding
    switch rem(nebytes, 4)
      case 2
        y = y(1:end-2);
      case 3
        y = y(1:end-1);
    end
end

%% reshape to a row vector and make it a character array
y = uint8(reshape(y, 1, numel(y)));

%% save to file if needed
if ~isempty(outfname)
  fid = fopen(outfname,'wb');
  fwrite(fid, y, 'uint8');  
  fclose(fid);
end