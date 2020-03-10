%UpdateXml_SpkGrps updates the xml files to read spike data from Klusters
%
%  USAGE
%
%    data = UpdateXml_SpkGrps(filename,<options>)
%
%    filename       xml file to read
%    <options>      optional list of property-value pairs (see table below)
%
%    =========================================================================
%     Properties    Values
%    -------------------------------------------------------------------------
%     'nSamples'            number of samples (default = 40)
%     'nFeatures'           number of features (default = 3)
%     'peakSampleIndex'     position of peak (default = 16)
%    =========================================================================
%
%    Dependencies: xmltools

% Copyright (C) 2016 Adrien Peyrache
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.


function UpdateXml_SpkGrps(fbasename,varargin)


% Default values
nFeatures = 3;
nSamples = 40;
peakSampleIndex = 16;
fctName = 'UpdateXml_SpkGrp';

if nargin < 1 || mod(length(varargin),2) ~= 0
  error(['Incorrect number of parameters (type ''help ' fctName ' ''for details).']);
end

% Parse options
for i = 1:2:length(varargin)
  if ~isa(varargin{i},'char')
    error(['Parameter ' num2str(i+3) ' is not a property (type ''help ' fctName ' ''for details).']);
  end
  switch(lower(varargin{i}))
    case 'nsamples'
      nSamples = varargin{i+1};
      if ~isa(nSamples,'numeric') || length(nSamples) ~= 1 || nSamples < 1
        error(['Incorrect value for property ''nSamples'' (type ''help ' fctName ' ''for details).']);
      end
    case 'peaksampleindex'
      peakSampleIndex = varargin{i+1};
      if ~isa(peakSampleIndex,'numeric') || length(peakSampleIndex) ~= 1 || peakSampleIndex < 1
        error(['Incorrect value for property ''peakSampleIndex'' (type ''help ' fctName ' ''for details).']);
      end  
    case 'nfeatures'
      nFeatures = varargin{i+1};
      if ~isa(nFeatures,'numeric') || length(nFeatures) ~= 1 || nFeatures < 1
        error(['Incorrect value for property ''nFeatures'' (type ''help ' fctName ' ''for details).']);
      end    
  end
end

xmli = strfind(fbasename,'.xml');
if ~isempty(xmli)
    fbasename = fbasename(1:xmli-1);
end
rxml = xmltools([fbasename '.xml']);
%keyboard

ix = 1;
while ~strcmp(rxml.child(2).child(ix).tag,'spikeDetection')
    ix = ix+1;
end

nCh = length(rxml.child(2).child(ix).child(1).child);
for ii=1:nCh
    %if length(rxml.child(2).child(ix).child(1).child(ii).child) == 1
    ixChannels = 1;
        while ~strcmp(rxml.child(2).child(ix).child(1).child(ii).child(ixChannels).tag,'channels')
            ixChannels = ixChannels + 1;
        end
        disp(ixChannels)
        tmp = rxml.child(2).child(ix).child(1).child(ii).child(ixChannels);
        tmpChild = repmat(tmp,[4,1]);
        tmpChild(2).tag = 'nSamples';
        tmpChild(2).value = num2str(nSamples);
        tmpChild(2).child = [];
        tmpChild(3).tag = 'nFeatures';
        tmpChild(3).value = num2str(nFeatures);
        tmpChild(3).child = [];
        tmpChild(4).tag = 'peakSampleIndex';
        tmpChild(4).value = num2str(peakSampleIndex);
        tmpChild(4).child = [];
        
        rxml.child(2).child(ix).child(1).child(ii).child = tmpChild;
    %end
end

xmltools(rxml,[fbasename '.xml'])
