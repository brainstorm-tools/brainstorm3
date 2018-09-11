% mff_importsignal - import information from MFF 'signal1.bin' file
%
% Usage:
%   data = mff_importsignal(mffFile, skipdataflag);
%
% Inputs:
%  mffFile      - filename/foldername for the MFF file
%  skipdataflag - [0|1] skip data flag, when set to 1, the data is not imported
%                 default is 0.
%
% Output:
%  data     - cell array of raw data (one cell is one block in the original
%             mff framework)
%  datasize - size of each block
%  srate    - sampling rate
%  npns     - number of PNS data channels

% This file is part of mffmatlabio.
%
% mffmatlabio is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% mffmatlabio is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with mffmatlabio.  If not, see <https://www.gnu.org/licenses/>.

function [floatData, allDataSize, frequencies, nChannels] = mff_importsignal(mffFile)

if nargin < 1
    help mff_importsignal;
    return;
end

p = fileparts(which('mff_importsignal.m'));
warning('off', 'MATLAB:Java:DuplicateClass');
%javaaddpath(fullfile(p, 'MFF-1.2.2-jar-with-dependencies.jar'));
warning('on', 'MATLAB:Java:DuplicateClass');

% Create a factory.
mfffactorydelegate = javaObject('com.egi.services.mff.api.LocalMFFFactoryDelegate');
mfffactory = javaObject('com.egi.services.mff.api.MFFFactory', mfffactorydelegate);
binfilenames = { [mffFile filesep 'signal1.bin'] [mffFile filesep 'signal2.bin'] };
if ~exist(binfilenames{2}) binfilenames(2) = []; end

floatData   = { [] [] };
allDataSize = { [] [] };
nChannels   = [0 0];
for iFile = 1:length(binfilenames)
    
    % Create Signal object and read in signal1.bin file.
    signalresourcetype = javaObject('com.egi.services.mff.api.MFFResourceType', javaMethod('valueOf', 'com.egi.services.mff.api.MFFResourceType$MFFResourceTypes', 'kMFF_RT_Signal'));
    signalResource = mfffactory.openResourceAtURI(binfilenames{iFile}, signalresourcetype);
    rVal = true;
    if ~isempty(signalResource)
        
        %try
        
        res = signalResource.loadResource();
        if res
            
            blocks = signalResource.getSignalBlocks();
            numblocks = signalResource.getNumberOfBlocks();
            
            if ~isempty(blocks)
                
                % before reading any data, look at info for each block
                blockIndex = 0;
                for x = 0:numblocks-1
                    block = blocks.get(x);
                    
                    if rVal
                        % Load the signal Blocks data
                        try
                            block = signalResource.loadSignalBlockData(block);
                        catch
                            errorCode = lasterror;
                            if strcmpi(errorCode.identifier, 'MATLAB:Java:GenericException')
                                error( [ 'You must increate Java Memory to read this file' 10 ...
                                    'On the Home tab, in the Environment section, click Preferences.' 10 ...
                                    'Select MATLAB > General > Java Heap Memory' 10 ...
                                    'You must restart Matlab after making this change.' 10 ...
                                    'If your Java memory is already at the maximum, the easiest' 10 ...
                                    'solution is to use another computer to import the file' ]);
                            else
                                error(lasterr);
                            end
                        end
                        
                        version    = block.version;
                        dataSize   = block.dataBlockSize;
                        allDataSize{iFile}(x+1) = dataSize;
                        nChannels(iFile) = block.numberOfSignals;
                        nSamples   = 0;
                        headerSize = block.headerSize;
                        
                        offsets     = block.offsets; % int array
                        signalDepth = block.signalDepth; % int array
                        frequencies = block.signalFrequency; % int array
                        
                        if isempty(offsets) || isempty(signalDepth) || isempty(frequencies)
                            error('Error: Arrays are null for block no. %d\n', blockIndex);
                        end
                        
                        typeSize = (signalDepth(1) / 8); % 8 bits
                        
                        % Determine the number of sample. Note the special check for only one channel.
                        if ~isempty(offsets) && nChannels(iFile)  > 1
                            nSamples = offsets(2) / typeSize;
                        else
                            if(nChannels(iFile)  == 1)
                                nSamples = dataSize / typeSize;
                            end
                        end
                        
                        if(blockIndex == 0)
                            fprintf('Signal Block Version Number: %d\n', version);
                            fprintf('Signal Block Data Size: %d\n', dataSize);
                            fprintf('Signal Block Header size. %d\n', headerSize);
                            fprintf('Number of Signals: %d\n', nChannels(iFile));
                            fprintf('Signal Block Samples: %d\n', nSamples);
                            fprintf('Sample Rate: %d\n', frequencies(1));
                            fprintf('Signal Depth: %d\n', signalDepth(1));
                            fprintf('---------------------------------\n');
                            
                            % Optional Header is usually only written to the
                            % first signal block of the signal file.
                            if ~isempty(block.optionalHeader)
                                
                                buffer = typecast(block.optionalHeader,'uint8');
                                
                                % Get the optional headers information. Please refer to the
                                % Meta File Format(MFF)documentation for more information about
                                % Signal files and the optional header.
                                
                                tmpType      = typecast(buffer(1:4),'int32');
                                numBlocks    = typecast(buffer(5:12),'int64');
                                totalSamples = typecast(buffer(13:20),'int64');
                                numSignals   = typecast(buffer(21:24),'int32');
                                
                                fprintf('Optional Header type: %d\n',tmpType);
                                fprintf('Optional Header number of blocks total: %d\n',numBlocks);
                                fprintf('Optional Header number of Samples total: %d\n',totalSamples);
                                fprintf('Optional Header number of Signals: %d\n',numSignals);
                                fprintf('------------------------------------------\n');
                                
                            end
                            
                        end
                        
                        % Get the data.
                        typeSize  = 4;
                        floatData{iFile}{blockIndex+1} = typecast(block.data,'single'); % WARNING LITTLE ENDIAN HERE
                        
                        % Note: the length of the buffer should match the Block data size.
                        if length(floatData{iFile}{blockIndex+1})*typeSize ~= dataSize
                            error('Error: Data buffer size mismatch\n');
                        end
                        floatData{iFile}{blockIndex+1} = reshape(floatData{iFile}{blockIndex+1}, nSamples, nChannels(iFile))';
                        
                        
                    else
                        error('Error Accessing signal data.\n');
                    end
                    blockIndex = blockIndex+1;
                end
            else
                error('Error: Empty block.\n');
            end
        else
            error('Error: Could not load the signal resource.\n');
        end
        
        %catch
        %    Logger.getLogger(MFFAPIExamples.class.getName()).log(Level.SEVERE, null, ex);
        %    rVal = false;
        % Additional cleanup as needed
        %end
        
    else
        error('Error: Can not open the signal resource.\n');
    end
    mfffactory.closeResource(signalResource);
end

% combine autonomous and EEG data
if ~isempty(floatData{2})
    
    % remove last channel of PNS data if null
    uniqueLastChan = unique(floatData{2}{1}(end,:));
    if length(uniqueLastChan) == 1 && uniqueLastChan == 0
        floatData{2} = cellfun(@(x)x(1:end-1,:), floatData{2}, 'uniformoutput', false);
    end
    nChannels(2) = size(floatData{2}{1},1);
    
    % concatenate PNS data and EEG data
    try
        for iSegment = 1:length(floatData{1})
            floatData{1}{iSegment} = [ floatData{1}{iSegment}; floatData{2}{iSegment} ];
        end
    catch
        error('Issue with concatenating the autonomous data and the EEG data');
    end
    floatData   = floatData{1};
    allDataSize = allDataSize{1} + allDataSize{2};
else
    floatData = floatData{1};
    allDataSize = allDataSize{1};
end


