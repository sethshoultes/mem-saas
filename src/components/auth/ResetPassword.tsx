import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { Button } from '../ui/button';
import { supabase } from '../../lib/supabase';
import { Lock, AlertCircle, CheckCircle2, Shield } from 'lucide-react';
import { validatePasswordStrength } from '../../lib/utils';

export function ResetPassword() {
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [validation, setValidation] = useState<{
    isValid: boolean;
    score: number;
    feedback: string[];
  }>({ isValid: false, score: 0, feedback: [] });
  const [success, setSuccess] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    // Check if we have a valid hash parameter
    if (!location.hash) {
      setError('Invalid or expired reset link');
    }
  }, [location]);

  useEffect(() => {
    if (password) {
      setValidation(validatePasswordStrength(password));
    }
  }, [password]);

  const validatePassword = () => {
    if (!validation.isValid) {
      setError('Password does not meet security requirements');
      return false;
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return false;
    }
    return true;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!validatePassword()) return;

    setIsLoading(true);
    setError(null);

    try {
      const { error } = await supabase.auth.updateUser({ password });
      
      if (error) throw error;
      
      setSuccess(true);
      setTimeout(() => {
        navigate('/');
      }, 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to reset password');
    } finally {
      setIsLoading(false);
    }
  };

  if (success) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-lg shadow-md p-8 max-w-md w-full">
          <div className="flex flex-col items-center text-center">
            <CheckCircle2 className="h-12 w-12 text-green-500 mb-4" />
            <h1 className="text-2xl font-bold text-gray-900 mb-2">
              Password Reset Successful
            </h1>
            <p className="text-gray-600 mb-4">
              Your password has been updated. You will be redirected to the login page.
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-md p-8 max-w-md w-full">
        <div className="flex flex-col items-center text-center mb-8">
          <Lock className="h-12 w-12 text-blue-500 mb-4" />
          <h1 className="text-2xl font-bold text-gray-900">
            Reset Your Password
          </h1>
          <p className="text-gray-600 mt-2">
            Please enter your new password below
          </p>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-50 rounded-lg flex items-start gap-3">
            <AlertCircle className="h-5 w-5 text-red-500 mt-0.5" />
            <p className="text-sm text-red-600">{error}</p>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label
              htmlFor="password"
              className="block text-sm font-medium text-gray-700 mb-2"
            >
              New Password
            </label>
            <input
              id="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className={`w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                password ? (validation.isValid ? 'border-green-500' : 'border-red-300') : 'border-gray-300'
              }`}
              required
            />
            {password && (
              <div className="mt-2">
                <div className="flex items-center gap-2 mb-2">
                  <Shield className={`h-4 w-4 ${
                    validation.score < 2 ? 'text-red-500' :
                    validation.score < 4 ? 'text-yellow-500' :
                    'text-green-500'
                  }`} />
                  <span className="text-sm font-medium">
                    Password Strength: {
                      validation.score < 2 ? 'Weak' :
                      validation.score < 4 ? 'Medium' :
                      'Strong'
                    }
                  </span>
                </div>
                <div className="space-y-1">
                  {validation.feedback.map((feedback, index) => (
                    <p key={index} className="text-sm text-red-600 flex items-center gap-2">
                      <AlertCircle className="h-3 w-3" />
                      {feedback}
                    </p>
                  ))}
                </div>
              </div>
            )}
          </div>

          <div>
            <label
              htmlFor="confirmPassword"
              className="block text-sm font-medium text-gray-700 mb-2"
            >
              Confirm New Password
            </label>
            <input
              id="confirmPassword"
              type="password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              className={`w-full px-3 py-2 border rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 ${
                confirmPassword ? (password === confirmPassword ? 'border-green-500' : 'border-red-300') : 'border-gray-300'
              }`}
              required
            />
          </div>

          <Button
            type="submit"
            className="w-full"
            disabled={isLoading}
          >
            {isLoading ? 'Resetting Password...' : 'Reset Password'}
          </Button>
        </form>
      </div>
  </div>
  );
}