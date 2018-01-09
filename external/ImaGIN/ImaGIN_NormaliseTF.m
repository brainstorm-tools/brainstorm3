function D = ImaGIN_NormaliseTF(S)
% Normalise several TF files according to a baseline file

% -=============================================================================
% This function is part of the ImaGIN software: 
% https://f-tract.eu/
%
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
%
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE AUTHORS
% DO NOT ASSUME ANY LIABILITY OR RESPONSIBILITY FOR ITS USE IN ANY CONTEXT.
%
% Copyright (c) 2000-2018 Inserm U1216
% =============================================================================-
%
% Authors: Olivier David

[Finter,Fgraph,CmdLine] = spm('FnUIsetup','TF',0);


%files to normalise
try
    DD = S.D;
catch
    DD = spm_select(inf, '\.mat$', 'Select TF EEG mat file(s) to normalise');
end
%baseline file
try
    BB = S.B;
catch
    BB = spm_select(inf, '\.mat$', 'Select TF EEG mat file(s) (baseline)');
end

if isempty(BB)
    try
        BB=S.B;
    catch
        BB = spm_input('Baseline time window (s)', '+1', 'r', '', 2);
    end
end

try
    clear tmp
    for i1=1:size(DD,1)
        tmp{i1} = spm_eeg_load(deblank(DD(i1,:)));
        Dname{i1}=DD(i1,:);
    end
    DD=tmp;
catch
    error(sprintf('Trouble reading file %s', DD));
end
if ~isnumeric(BB)
    try
        clear tmp
        for i1=1:size(BB,1)
            tmp{i1} = spm_eeg_load(deblank(BB(i1,:)));
            Bname{i1}=BB(i1,:);
        end
        BB=tmp;
    catch
        error(sprintf('Trouble reading file %s', B));
    end
end

if ~isnumeric(BB)
    if isfield(BB{1}, 'Nfrequencies') && isfield(DD{1},'Nfrequencies')
        s=zeros(BB{1}.Nfrequencies,BB{1}.nchannels);
        m=zeros(BB{1}.Nfrequencies,BB{1}.nchannels);
        for i1=1:size(BB{1},1)
            tmp=[];
            for i2=1:length(BB)
                tmp=[tmp squeeze(double(BB{i2}(i1,:,:)))];
            end
            s(:,i1)=std(tmp,[],2);
            m(:,i1)=mean(tmp,2);
        end
        s(find(s<=10*eps))=1;    %because otherwise it gives inf for normalised data
        for i2=1:length(DD)
            D=DD{i2};
            if (BB{1}.Nfrequencies == D.Nfrequencies) && (BB{1}.nchannels == D.nchannels)
                data=D(:,:,:,:);
                for i1=1:D.nchannels
                    for i2=1:D.ntrials
                        ss=s(:,i1)*ones(1,D.nsamples);
                        mm=m(:,i1)*ones(1,D.nsamples);
                        data(i1,:,:,i2)=(squeeze(data(i1,:,:,i2))-mm)./ss;
                    end
                end
                D.tf.Label=['Normalised ' lower(D.tf.Label)];
                D=clone(D,['n' D.fname],[D.nchannels D.Nfrequencies D.nsamples D.ntrials]);
                D(:,:,:,:)=data;
                save(D);
            end
        end
    else
        error('No time frequency data');
    end
else
    if isfield(DD{1},'Nfrequencies')
        for i2=1:length(DD)
            index=find(DD{i2}.tf.time>=min(BB)&DD{i2}.tf.time<=max(BB));
            D=DD{i2};
            data=D(:,:,:,:);
            for i1=1:D.nchannels
                for i2=1:D.ntrials
                    tmp=squeeze(double(data(i1,:,index,i2)));
                    ss=std(tmp,[],2)*ones(1,D.nsamples);
                    mm=mean(tmp,2)*ones(1,D.nsamples);
                    ss(find(ss<=10*eps))=1;    %because otherwise it gives inf for normalised data
                    data(i1,:,:,i2)=(squeeze(data(i1,:,:,i2))-mm)./ss;
                end
            end
            D.tf.Label=['Normalised ' lower(D.tf.Label)];
            D=clone(D,['n' D.fname],[D.nchannels D.Nfrequencies D.nsamples D.ntrials]);
            D(:,:,:,:)=data;
            save(D);
        end
    else
        error('No time frequency data');
    end
end


