function initializeProbeFile(convertedRawFilename, output_dir, ChannelMat)

% convertedRawFilename = 'asjhgfjhsdgf' % no extension
% output_dir           = 'F:\Adrien\spyking circus test\';

% probe_file = 'F:\Adrien\spyking circus test\020_AA.prb';
% output_dir = 'F:\Adrien\spyking circus test';


output_dir = 'C:\Users\McGill\Desktop';
convertedRawFilename = 'a';




outFid = fopen(fullfile(output_dir, [convertedRawFilename '.prb']), 'w');

Channels = ChannelMat.Channel;

%% Get which channels belong to which montages
nChannels = length(Channels);


AssignedToMontages = find(cellfun(@isempty,{Channels.Group}));



Montages = unique({Channels.Group});


%% Input the 
fprintf(outFid,['total_nb_channels	=  %s\n' ...
'radius	= 100\n' ...
'channel_groups = {\n'], num2str(nChannels));




                    fclose(outFid)






for iMontage = 1:nMontages







for iCHannel = 1:length(nChannelsINMontraes)

if all(Loc == 0)
    do the regular
    
    
else
    NEEDS CONVERSION FROM 3D TO 2D
end












 0: {'channels':[0, 1, 2, 3],
	'graph': [],
	'geometry': {0: [0, 0], 1: [0, 1], 2: [0, 2], 3: [0, 3]}
	},
 1: {'channels':[4, 5, 6, 7],
	'graph': [],
	'geometry': {4: [200, 0], 5: [200, 1], 6: [200, 2], 7: [200, 3]}
	},
 2: {'channels':[8, 9, 10, 11],
	'graph': [],
	'geometry': {8: [400, 0], 9: [400, 1], 10: [400, 2], 11: [400, 3]}
	},	
 3: {'channels':[12, 13, 14, 15],
	'graph': [],
	'geometry': {12: [600, 0], 13: [600, 1], 14: [600, 2], 15: [600, 3]}
	},	
 4: {'channels':[16, 17, 18, 19],
	'graph': [],
	'geometry': {16: [800, 0], 17: [800, 1], 18: [800, 2], 19: [800, 3]}
	},		
 5: {'channels':[20, 21, 22, 23],
	'graph': [],
	'geometry': {20: [1000, 0], 21: [1000, 1], 22: [1000, 2], 23: [1000, 3]}
	},		
 6: {'channels':[24, 25, 26, 27],
	'graph': [],
	'geometry': {24: [1200, 0], 25: [1200, 1], 26: [1200, 2], 27: [1200, 3]}
	},
 7: {'channels':[28, 29, 30, 31],
	'graph': [],
	'geometry': {28: [1400, 0], 29: [1400, 1], 30: [1400, 2], 31: [1400, 3]}
	},	
 8: {'channels':[32, 33, 34, 35],
	'graph': [],
	'geometry': {32: [1600, 0], 33: [1600, 1], 34: [1600, 2], 35: [1600, 3]}
	},	
}

































end