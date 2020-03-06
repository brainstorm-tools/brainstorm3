function SpyCircus2Neuroscope(convertedFilePath, convertedFileBase, varargin)
% Generates output compatiblewith the Neurosuite from Spyking Circus data
% 
% USAGE
%
% SpyCircus2Neuroscope(resultFolder)
% Should be run from the data folder, and file basenames are the
% same as the name as current directory
%
%
% INPUTS
% resultFolder          specify the location of the results
% fbasename (optional)  file basenames (of the dat and xml files)
% 
% Copyright (C) 2019 Adrien Peyrache
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.


%% Testing parameters

convertedFilePath = 'F:\Adrien\Ripples\AA20_d4_20171205-103721-001-p001_0\AA20_d4_20171205-103721-001-p001_0'
convertedFileBase = 'AA20_d4_20171205-103721-001-p001_0';




hdfBaseName = fullfile(convertedFilePath,convertedFileBase);

temp_shape = hdf5read([hdfBaseName '.templates.hdf5'],'/temp_shape');
tempNb = temp_shape(3)/2;
chNb = temp_shape(1);
sampleNb = temp_shape(2);

temp_x = hdf5read([hdfBaseName '.templates.hdf5'],'/temp_x');
temp_y = hdf5read([hdfBaseName '.templates.hdf5'],'/temp_y');
temp_data = hdf5read([hdfBaseName '.templates.hdf5'],'/temp_data');

temp_data = full(sparse(double(temp_x)+1,double(temp_y)+1,double(temp_data)));
temp_data = temp_data(:,1:tempNb);
temp_data = reshape(temp_data,[sampleNb chNb tempNb]);

XMLfile = fullfile(convertedFilePath,[convertedFileBase '.xml']);
if ~exist(XMLfile,'file')
    error('Error: no xml file')
end

par = LoadXml(XMLfile);
elecGpNb = length(par.ElecGp); %Number of electrode groups
elecGp   = zeros(tempNb,1); %indices of electrode group of each cell
elecGpClu    = cell(elecGpNb,1); %vectors of clu indices
elecGpNbClu  = zeros(elecGpNb,1); %number of clusters per group
elecGpSpkT   = cell(elecGpNb,1); %vectors of spike times

for c=1:tempNb
    
    [~,chIx]    = max(sum(temp_data(:,:,c).^2));
    e = 1;
    while ~ismember(chIx,par.ElecGp{e}+1)    
        e = e+1;
    end    
    elecGp(c) = e;
    
    %spike times;
    dset = ['/spiketimes/temp_' num2str(c-1)];
    cellSpkT    = hdf5read([hdfBaseName '.result.hdf5'],dset);
    
    if ~elecGpNbClu(e)
        elecGpSpkT{e}   = cellSpkT;
        elecGpClu{e}    = 2*ones(length(cellSpkT),1);
    else
        elecGpSpkT{e}   = [elecGpSpkT{e};cellSpkT];
        elecGpClu{e}    = [elecGpClu{e};2*ones(length(cellSpkT),1) + elecGpNbClu(e)]; %clu indices start at 2;
    end
    elecGpNbClu(e)  = elecGpNbClu(e)+1;
     
end

%Write clu & res
for e=1:elecGpNb
    spkT    = elecGpSpkT{e};
    if ~isempty(spkT)
        [elecGpSpkT{e},spkIx]    = sort(spkT,'ascend');
        fname   = [convertedFileBase '.res.' num2str(e)];
        fid     = fopen(fname,'w');
        fprintf(fid,'%.0f\n',elecGpSpkT{e});
        fclose(fid);
        clear fid

        clu = elecGpClu{e};
        nClu = length(unique(clu));
        clu = [nClu;clu(spkIx)];
        fname   = [convertedFileBase '.clu.' num2str(e)];
        fid     = fopen(fname,'w');
        fprintf(fid,'%.0f\n',clu);
        fclose(fid);
        clear fid
    end
    
end

%Load and write spikes, Compute and write fet files

for e = 1:elecGpNb
    if ismember(e,elecGp)
        waveforms = load_spk_from_dat(convertedFileBase,e);
        fid       = fopen([convertedFileBase,'.spk.',num2str(e)],'w');
        fwrite(fid,waveforms(:),'int16');
        fclose(fid);

        PCAs_global = zeros(3,size(waveforms,1),size(waveforms,3));
        
        for k = 1:size(waveforms,1)
            PCAs_global(:,k,:) = pca(zscore(permute(double(waveforms(k,:,:)),[2,3,1]),[],2),'NumComponents',3)';
         end
        
        PCAs_global = reshape(PCAs_global,size(PCAs_global,1)*size(PCAs_global,2),size(PCAs_global,3));
        factor      = (2^15)./max(abs(PCAs_global'));
        PCAs_global = int64(PCAs_global .* factor');

        waveforms = reshape(waveforms,[size(waveforms,1)*size(waveforms,2),size(waveforms,3)]);
        wpowers   = sum(waveforms.^2,1)/size(waveforms,1)/100;
        wranges   = range(waveforms,1);

        fid       = fopen([convertedFileBase,'.fet.',num2str(e)],'w');
        Fet       = double([PCAs_global; int64(wranges); int64(wpowers); elecGpSpkT{e}']);
        nFeatures = size(Fet, 1);
        
        formatstring = '%d';
        for ii=2:nFeatures
            formatstring = [formatstring,'\t%d'];
        end
        formatstring = [formatstring,'\n'];

        fprintf(fid, '%d\n', nFeatures);
        fprintf(fid,formatstring,Fet);
        fclose(fid);
    
    end
end

UpdateXml_SpkGrps(convertedFileBase)


        
        