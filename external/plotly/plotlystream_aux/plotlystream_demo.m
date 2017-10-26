%----STORED STREAMING CREDENTIALS----%
my_credentials = loadplotlycredentials;
try
    my_stream_token = my_credentials.stream_ids{1};
catch
    fprintf(['\nOops - No stream_keys found! please run: >>saveplotlycredentials(',...
        ' ''username'',''api_key'',''stream_key).'' \n',...
        'Your stream key(s) can be found online at: https://plot.ly or contact chuck@plot.ly',...
        'for more information.\n\n']);
    return
end

%----SETUP-----%

p = plotlyfig('visible','off'); 
p.data{1}.x = []; 
p.data{1}.y = [];
p.data{1}.type = 'scatter';
p.data{1}.stream.token = my_stream_token; 
p.data{1}.stream.maxpoints = 30;  
p.PlotOptions.Strip = false; 
p.PlotOptions.FileName = 'stream_test'; 
p.PlotOptions.FileOpt = 'overwrite'; 

%----PLOTLY-----%

p.plotly; 

%----CREATE A PLOTLY STREAM OBJECT----%

ps = plotlystream(my_stream_token);

%----OPEN THE STREAM----%

ps.open(); 

%----WRITE TO THE STREAM----%

for i = 1:2000
    mydata.x = i; 
    mydata.y = rand; 
    ps.write(mydata);
    %take a breath 
    pause(0.05); 
end

%----CLOSE THE STREAM----% 
ps.close; 

