%function [xml, rxml] = LoadXml(FileBase)
%
% loads the xml file using xmltools (have to have it in the path)
% rxml returns it's original layout - very messy structure but contains all
% the xml file contents.
% xml - is the ouput structure which is backwards compatible to LoadPar
% output, so you can use it instead ..also loads some usefull stuff -
% Anatomoical groups with Skips , Spike electrode groups
% more can be added later (e.g. parameters of the process scripts)
% this script is written for xml version 1.1 .. older version doesn't work.
% additions are welcome

function [xml, rxml] = LoadXml(fbasename,varargin)

xml = struct;

xmli = strfind(fbasename,'.xml');
if isempty(xmli)
   fbasename = [fbasename '.xml'];
end
rxml = xmltools(fbasename);

rxml = rxml.child(2);

% from this level all children are the different parameters fields
xml.FileName = fbasename;

for i=1:length(rxml.child)

    switch lower(rxml.child(i).tag)
        
        case 'generalinfo'
            xml.Date = rxml.child(i).child(1).value; % date of xml file creation?

        case 'acquisitionsystem'
            xml.nBits = str2num(rxml.child(i).child(1).value); % number of bits of the file
            xml.nChannels = str2num(rxml.child(i).child(2).value);
            xml.SampleRate = str2num(rxml.child(i).child(3).value);
            xml.SampleTime = 1e6/xml.SampleRate; %to make backwards compatible
            xml.VoltageRange = str2num(rxml.child(i).child(4).value);
            xml.Amplification = str2num(rxml.child(i).child(5).value);
            xml.Offset =  str2num(rxml.child(i).child(6).value);
            
        case 'fieldpotentials'
            xml.lfpSampleRate = str2num(rxml.child(i).child.value);
            
        case 'anatomicaldescription'
            tmp = rxml.child(i).child.child;
            for grpI =1:length(tmp)
                for chI=1:length(tmp(grpI).child)
                    xml.AnatGrps(grpI).Channels(chI) = str2num(tmp(grpI).child(chI).value);
                    xml.AnatGrps(grpI).Skip(chI) = str2num(tmp(grpI).child(chI).attribs.value);
                end
            end
            
        case 'spikedetection'
            if ~isempty(rxml.child(i).child)
                tmp =rxml.child(i).child.child;
                for grpI =1:length(tmp)
                    for chI=1:length(tmp(grpI).child(1).child)
                        xml.SpkGrps(grpI).Channels(chI) = str2num(tmp(grpI).child(1).child(chI).value);
                    end
                    if length(tmp(grpI).child)>1
                        xml.SpkGrps(grpI).nSamples = str2num(tmp(grpI).child(2).value);
                        xml.SpkGrps(grpI).PeakSample = str2num(tmp(grpI).child(3).value);
                        xml.SpkGrps(grpI).nFeatures = str2num(tmp(grpI).child(4).value);
                    end
                    %backwards compatibility
                    xml.nElecGps = length(tmp);
                    xml.ElecGp{grpI} = xml.SpkGrps(grpI).Channels;
                end
            else
                xml.nElecGps = 0;
            end


        case 'programs'
            tmp = rxml.child(i).child;
            for i=1:length(tmp)
                if strcmp(tmp(i).child(1).value,'process_mhipass')
                    for j=1:length(tmp(i).child(2).child )
                        if strcmp(tmp(i).child(2).child(j).child(1).value,'frequency')
                            xml.HiPassFreq = str2num(tmp(i).child(2).child(j).child(2).value);
                            break
                        end
                    end
                end
            end
    end


end


% general recursive parsing will have to wait.
