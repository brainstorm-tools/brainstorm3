function y = generateBoxData(outliers, boxmin, Q2, med, Q3, boxmax)

%set number of data points
N = numel(outliers)*5+20;

%find percentile numbers
Q1Index = round(N*25/100);
Q2Index = round(N*50/100);
Q3Index = round(N*75/100);

outlierlow = outliers(outliers<med);
outlierhigh = outliers(outliers>med);

y=[outlierlow ...
    linspace(boxmin, Q2, Q1Index-numel(outlierlow)) ...
    linspace(Q2, med, Q2Index-Q1Index) ...
    linspace(med, Q3, Q3Index-Q2Index) ...
    linspace(Q3, boxmax, N-Q3Index-numel(outlierhigh)) ...
    outlierhigh];

end