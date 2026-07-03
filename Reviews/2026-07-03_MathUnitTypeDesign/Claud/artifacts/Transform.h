#pragma once

#include "Core/Public/Math/Vector.h"
#include "Core/Public/Math/Vector2D.h"
#include "Core/Public/Math/Quaternion.h"
#include "Core/Public/Math/Matrix4x4.h"

// ============================================================================
// Transform
// ----------------------------------------------------------------------------
// 월드 객체의 지역 좌표계를 표현하는 3D 트랜스폼입니다. (TRS)
//
// 위치(Vector) + 회전(Quaternion) + 스케일(Vector)을 들고,
// 4x4 월드 행렬은 필요할 때 파생한다(저장하지 않는다).
//
// #4 2D 월드는 평면 제약으로 사용한다: z 고정, Z축 회전만.
// 편의 생성자 FromPlanar가 그 제약을 표현한다.
// ============================================================================

struct Transform
{
	Vector position = Vector::Zero();
	Quaternion rotation = Quaternion::Identity();
	Vector scale = Vector::One();

	constexpr Transform() = default;

	constexpr Transform(const Vector& inPosition, const Quaternion& inRotation, const Vector& inScale)
		: position(inPosition)
		, rotation(inRotation)
		, scale(inScale)
	{
	}

	static constexpr Transform Identity()
	{
		return Transform(Vector::Zero(), Quaternion::Identity(), Vector::One());
	}

	// #4 평면 편의 생성자입니다. XY 평면 위치 + Z축 회전 + XY 스케일.
	static Transform FromPlanar(const Vector2D& planarPosition, float rotationZ, const Vector2D& planarScale)
	{
		return Transform(
			Vector(planarPosition.x, planarPosition.y, 0.0f),
			Quaternion::FromAngleZ(rotationZ),
			Vector(planarScale.x, planarScale.y, 1.0f));
	}

	// 이 트랜스폼의 월드 행렬입니다. Scale * Rotate * Translate.
	Matrix4x4 ToMatrix() const
	{
		return Matrix4x4::Compose(position, rotation, scale);
	}

	// 지역 점을 월드로 변환합니다. 행렬을 만들지 않고 직접 계산합니다.
	Vector TransformPoint(const Vector& localPoint) const
	{
		const Vector scaled(localPoint.x * scale.x, localPoint.y * scale.y, localPoint.z * scale.z);

		return rotation.Rotate(scaled) + position;
	}

	// 객체 지역 축입니다(회전 적용). 객체가 바라보는 "앞/오른쪽/위"입니다.
	Vector Right() const
	{
		return rotation.Rotate(Vector::Right());
	}

	Vector Up() const
	{
		return rotation.Rotate(Vector::Up());
	}

	Vector Forward() const
	{
		return rotation.Rotate(Vector::Forward());
	}
};

static_assert(sizeof(Transform) == sizeof(float) * 10, "Transform must remain tight 40-byte storage (Vector + Quaternion + Vector).");
