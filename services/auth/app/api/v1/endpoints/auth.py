from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.auth import Token, UserLogin
from app.services.auth import AuthService
from app.services.user import UserService

router = APIRouter()


@router.post("/login", response_model=Token)
async def login(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> Token:
    """OAuth2 compatible token login."""
    user_service = UserService(db)
    auth_service = AuthService(db)
    
    # Authenticate user
    user = await user_service.authenticate(
        email=form_data.username,  # OAuth2 spec uses 'username'
        password=form_data.password,
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inactive user",
        )
    
    # Create session
    session = await auth_service.create_session(
        user=user,
        ip_address=request.client.host,
        user_agent=request.headers.get("User-Agent"),
    )
    
    return Token(
        access_token=session.token,
        refresh_token=session.refresh_token,
        token_type="bearer",
    )


@router.post("/logout")
async def logout(
    current_user: Annotated[User, Depends(get_current_user)],
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Logout current user."""
    auth_service = AuthService(db)
    await auth_service.logout_user(current_user.id)
    return {"message": "Successfully logged out"}


@router.post("/refresh", response_model=Token)
async def refresh_token(
    refresh_token: str,
    db: AsyncSession = Depends(get_db),
) -> Token:
    """Refresh access token."""
    auth_service = AuthService(db)
    
    try:
        new_tokens = await auth_service.refresh_access_token(refresh_token)
        return Token(
            access_token=new_tokens["access_token"],
            refresh_token=new_tokens["refresh_token"],
            token_type="bearer",
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )


@router.post("/register")
async def register(
    user_data: UserLogin,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Register new user."""
    user_service = UserService(db)
    
    # Check if user exists
    existing_user = await user_service.get_by_email(user_data.email)
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    
    # Create user
    user = await user_service.create_user(
        email=user_data.email,
        password=user_data.password,
        username=user_data.email.split("@")[0],  # Default username from email
    )
    
    return {
        "message": "User created successfully",
        "user_id": str(user.id),
        "email": user.email,
    }


@router.get("/me")
async def get_current_user_info(
    current_user: Annotated[User, Depends(get_current_user)],
) -> dict:
    """Get current user information."""
    return {
        "id": str(current_user.id),
        "email": current_user.email,
        "username": current_user.username,
        "full_name": current_user.full_name,
        "role": current_user.role,
        "is_active": current_user.is_active,
        "is_verified": current_user.is_verified,
        "mfa_enabled": current_user.mfa_enabled,
        "created_at": current_user.created_at.isoformat(),
    }