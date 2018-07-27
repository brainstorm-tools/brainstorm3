function [ChannelsPerGroupSuperficialToDeep,SpatialChannelXY,NumChansPerProbe,GroupsPerChannel] =...
    bz_ReadProbeGeometryFiles(probemaplist)
% USAGE
% [ChannelsPerGroupSuperficialToDeep,SpatialChannelXY,NumChansPerProbe,GroupsPerChannel] =...
%     bz_ReadProbeGeometryFiles(probemaplist)
% 
% INPUTS
%       probemaplist      - character cell (cell array of strings), each
%           string is the name of a probemap .xlsx file that is on the
%           matlab path.  these are typically at
%           /buzcode/generalComputation/gemetries
%       
%           Probe .xlsx files must have the following format features:
%                       - A column with row 1 having text "BY VERTICAL POSITION/SHANK (IE FOR DISPLAY)".
%                       In this row must be cells specifying SHANK 1, 
%                       SHANK 2, etc.  
%                       - Two rows right of that a column with channel
%                       numbers listed from superficial to deep in the
%                       shank group specified two to the left.      
%                   See NRX_Buzsaki32_4X8.xlsx or NRX_Buzsaki64_6X10.xlsx
%                   as templates
%
%
% OUTPUTS
%       ChannelsPerGroupSuperficialToDeep - Cell array of cell arrays, 
%           one cell compartment per probe.  Per-probe cell arrays list 
%           channels in each spike group, in format of a
%           cellarray of vectors, each vector is the channels in a spike
%           group, most superficial channel listed first in each vector,
%           most deep is last.  One 
%       SpatialChannelXY - Cell array of double arrays, one cell compartment
%           per probe.  The double arrays per probe, are nchannels x 3 
%           giving within-probe geometry in probe -centric coordinates.  In
%           some probes the 0,0 point is the bottom site of shank 1.
%           Column 1 = channel number
%           Column 2 = X coordinate (horizontal) coord within probe
%           Column 3 = Y coordinate (horizontal) coord within probe
%       NumChansPerProbe - Cell array of double arrays, one cell compartment
%           per probe.  Single number per probe denoting number of channels 
%           in each probe 
%       GroupsPerChannel - Cell array of double arrays, one cell compartment
%           per probe.  Single number per probe denoting number of groups 
%           in each probe
%
% DESCRIPTION
%
% Uses xlsread to open the specified .xlsx file, finds columns with
% specificaions as above, finds channels within shanks/spike groups
% assuming they are listed in the .xlsx file in superficial-to-deep order.
% Also gathers probe geometry by looking for columns with "X" and "Y" at
% tops.
%
% Current format of .xlsx files was totally rushed and seat of the pants,
% my want to modify them.  
% 
% See NRX_Buzsaki32_4X8.xlsx or NRX_Buzsaki64_6X10.xlsx as templates
%
% SEE ALSO
% 
% 
% Brendon Watson 2017                   


% grouplist_all = [];
% groupchans_all = [];
% channelcountoffset = 0;
for pmidx = 1:length(probemaplist)
    tpf = probemaplist{pmidx};
    if length(probemaplist{pmidx}) <= 4 || ~strcmp(probemaplist{pmidx}(end-4:end),'.xlsx')
        tpf = strcat(tpf,'.xlsx');
    end
    tpp = which(tpf);
    [tpnum,tptxt,tpraw] = xlsread(tpp,1);
    
    %find shanks/groups
    groupcolumn = strmatch('BY VERTI',tptxt(1,:));
    groupdenoterows = strmatch('SHANK ',tptxt(:,groupcolumn));
    groupperchannel = [];
    for ridx = 1:length(groupdenoterows);
       groupperchannel = cat(1,groupperchannel,str2num(tptxt{groupdenoterows(ridx),groupcolumn}(7:end))); 
    end
    grouplist_byprobe{pmidx} = unique(groupperchannel);
%     grouplist_all = cat(1,grouplist_all,unique(groupperchannel));
    
    %find channels
    channelcolumn = groupcolumn+2;%may definitely want to change this
%     groupcolumn = strmatch('Neuroscope channel',tptxt(1,:));
    tc = tpraw(groupdenoterows,channelcolumn);
    for cidx = 1:length(tc)
        channelnums(cidx,1) = tc{cidx};
    end
    
    %for each group, find the channels in it, save in sequence
    for gidx = 1:length(grouplist_byprobe{pmidx})
       tgidx = groupperchannel==grouplist_byprobe{pmidx}(gidx);%find rows whith this group/shank denotation 
       ChannelsPerGroupSuperficialToDeep{pmidx,gidx} = channelnums(tgidx);
%        groupchans_all = cat(1,groupchans_all,channelnums(tgidx)); 
    end
    NumChansPerProbe(pmidx) = length(channelnums);
%     channelcountoffset = NumChansPerProbe(pmidx);
%     numchans = length(groupchans_all);

%% Get XY information per channel
    Xcolumn = strmatch('X',tptxt(1,:));
    Ycolumn = strmatch('Y',tptxt(1,:));
    if isempty(Xcolumn) | isempty(Ycolumn)
        warning(['No/Insufficient XY information found in probe channel .xlsx file for ' tpf])
        SpatialChannelXY{pmidx} = [];
    else
        tx = tpraw(groupdenoterows,Xcolumn);
        ty = tpraw(groupdenoterows,Ycolumn);
        for cidx = 1:length(tx)
            X(cidx,1) = tx{cidx};
            Y(cidx,1) = ty{cidx};
        end
        SpatialChannelXY{pmidx} = [channelnums X Y];
    end
    GroupsPerChannel{pmidx} = groupperchannel(channelnums+1);
    clear channelnums X Y
end
1;