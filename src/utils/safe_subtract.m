function result = safe_subtract(A, B)
%SAFE_SUBTRACT Safely subtracts two matrices, handling empty inputs.
%
%   result = safe_subtract(A, B)
%
%   Description:
%       This function robustly performs the subtraction A - B, correctly
%       handling cases where either A, B, or both are empty matrices ([]).
%       Standard MATLAB subtraction can throw dimension mismatch errors when
%       one operand is empty and the other is not, which this function avoids.
%
%   Inputs:
%       A - The first operand (matrix or vector).
%       B - The second operand (matrix or vector).
%
%   Output:
%       result - The result of the subtraction.

    if isempty(A) && isempty(B)
        % If both are empty, the result is empty.
        result = [];
    elseif isempty(B)
        % If B is empty, the result is A.
        result = A;
    elseif isempty(A)
        % If A is empty, the result is -B.
        result = -B;
    else
        % If neither are empty, perform standard subtraction.
        result = A - B;
    end
end