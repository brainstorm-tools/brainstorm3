function data = filtfilt_hilbert ( num, den, data, hilbert )

% provided by Ricardo Bruña, Universidad Complutense de Madrid, 2022

% Checks if the filter is provided in second order sections.
if size ( num, 2 ) == 6 && all ( num ( :, 4 ) == 1 )
    
    % Gets the SOS matrix and the gain vector.
    SOS = num;
    G   = den;
    
    % Redefines the numerator and denominator from the SOS matrix.
    num = SOS ( :, 1: 3 )';
    den = SOS ( :, 4: 6 )';
    
    % Adds the excess G to the last filter.
    if numel ( G ) > size ( num, 2 )
        G ( size ( num, 2 ) ) = prod ( G ( size ( num, 2 ): end ) );
        G ( size ( num, 2 ) + 1: end ) = [];
    end
    
    % Corrects the numerator using the gains vector.
    for findex = 1: numel ( G )
        num ( :, findex ) = num ( :, findex ) * G ( findex );
    end
    
% Writes the filter coeficents as column vectors.
else
    num = num (:);
    den = den (:);
end


% % If IIR filter, relies on matlab filtfilt function.
% if exist ( 'SOS', 'var' ) && exist ( 'G', 'var' )
%     
%     warning ( 'Passing the data and the second-order sections to ''filtfilt''.' );
%     data = filtfilt ( SOS, G, data );
%     return
%     
% elseif ~isscalar ( den )
%     
%     warning ( 'Passing the data and the IIR filter to ''filtfilt''.' );
%     data = filtfilt ( den, num, data );
%     return
% end


% If empty, sets to false the 'perform Hilbert filtering' variable.
if nargin < 4, hilbert = false; end

% If vector array, converts it to column array.
if size ( data, 1 ) == 1, transposed = true;
else,                     transposed = false;
end

% Transposes the input, if necesary.
if transposed, data = shiftdim ( data, -1 ); end

% Gets the metadata.
shape    = size ( data );
samples  = shape (1);

% Calculates the padding order as the sum of all the orders.
border   = numel ( num ) - size ( num, 2 );
aorder   = numel ( den ) - size ( den, 2 );
order    = border + aorder;

% Reshapes the input data into 2D data.
data     = reshape ( data, samples, [] );

% The maximum filter order is a third of the data length.
if order > samples / 3, error ( 'Data must have length more than 3 times filter order.' ); end


% Calculates the 'butterfly' reflections to pad the data.
prepad   = bsxfun ( @minus, 2 * data ( 1,   : ), data ( order + 1: -1: 2, : ) );
pospad   = bsxfun ( @minus, 2 * data ( end, : ), data ( end - 1: -1: end - order, : ) );
paddata  = cat  ( 1, prepad, data, pospad );


% Gets the optimal FFT length.
chunksize = 50000;
chunksize = min ( chunksize, samples );
nfft      = optnfft ( chunksize + 2 * order );
chunksize = nfft - 2 * order;


% Gets the squared module of the FFT of the filter.
f_num    = fft ( num, nfft, 1 );
f_den    = fft ( den, nfft, 1 );

% Combines all the numerators and denominators.
f_num    = prod ( f_num, 2 );
f_den    = prod ( f_den, 2 );

% Combines numerator and denominator.
f_filter = f_num ./ f_den;
f_filter = f_filter .* conj ( f_filter );


% Applies the Hilbert filter, if desired.
if hilbert
    
    % Removes the negative part of the spectrum.
    f_filter ( ceil ( ( nfft + 1 ) / 2 + 1 ): end ) = 0;
    
    % Duplicates the positive part of the spectrum.
    f_filter ( 2: floor ( ( nfft + 1 ) / 2 ) ) = 2 * f_filter ( 2: floor ( ( nfft + 1 ) / 2 ) );
end

% Replicates the filter to match the size of the data.
f_filter = f_filter ( :, ones ( 1, size ( paddata, 2 ) ) );


% Takes overlapping data chunks.
for index = 1: ceil ( samples / chunksize )
    
    offset   = ( index - 1 ) * chunksize;
    chunklen = min ( chunksize, samples - offset );
    
    % Gets the current chunk of data.
    chunk    = paddata ( offset + ( 1: chunklen + 2 * order ), : );
    
    % Applies the filter using the FFT.
    f_chunk  = fft ( chunk, nfft, 1 );
    f_chunk  = f_chunk .* f_filter;
    chunk    = ifft ( f_chunk, nfft, 1 );
    
    % Stores the filtered chunk of data.
    data ( offset + ( 1: chunklen ), : ) = chunk ( order + ( 1: chunklen ), : );
end

% Restores the data shape.
data     = reshape ( data, shape );

% Transposes the output, if necesary.
if transposed, data = shiftdim ( data, 1 ); end


function nfft = optnfft ( samples )

% Skips this step, as it takes too long.
nfft = samples;

% % Looks for the optimal number of points of the FFT.
% 
% % Checks the factors of the next 1000 possible FFT lengths.
% nffts = ( 0: 1000 ) + samples;
% maxs = cellfun ( @(x) sum ( factor ( x ) ), num2cell ( nffts ) );
% 
% % Selects the length with the lower factors.
% [ ~, optimal ] = min ( maxs );
% nfft = nffts ( optimal );
