module lang::ecore::Ecore

import util::Maybe;
import lang::ecore::Refs;

data EClass
  = EClass(str \name = ""
      , str \instanceClassName = ""
      , str \instanceTypeName = ""
      , list[EAnnotation] \eAnnotations = []
      , list[ETypeParameter] \eTypeParameters = []
      , bool \abstract = false
      , bool \interface = false
      , list[lang::ecore::Refs::Ref[EClass]] \eSuperTypes = []
      , list[EOperation] \eOperations = []
      , list[EStructuralFeature] \eStructuralFeatures = []
      , list[EGenericType] \eGenericSuperTypes = []
      , lang::ecore::Refs::Id uid = noId())
  ;

data ETypeParameter
  = ETypeParameter(str \name = ""
      , list[EAnnotation] \eAnnotations = []
      , list[EGenericType] \eBounds = []
      , lang::ecore::Refs::Id uid = noId())
  ;

data ENamedElement
  = ENamedElement(ETypedElement \eTypedElement
      , str \name = \eTypedElement.\name
      , list[EAnnotation] \eAnnotations = \eTypedElement.\eAnnotations
      , bool \ordered = \eTypedElement.\ordered
      , bool \unique = \eTypedElement.\unique
      , int \lowerBound = \eTypedElement.\lowerBound
      , int \upperBound = \eTypedElement.\upperBound
      , lang::ecore::Refs::Ref[EClassifier] \eType = \eTypedElement.\eType
      , EGenericType \eGenericType = \eTypedElement.\eGenericType
      , Id uid = \eTypedElement.uid
      , bool _inject = true)
  | ENamedElement(EPackage \ePackage
      , str \name = \ePackage.\name
      , list[EAnnotation] \eAnnotations = \ePackage.\eAnnotations
      , str \nsURI = \ePackage.\nsURI
      , str \nsPrefix = \ePackage.\nsPrefix
      , list[EClassifier] \eClassifiers = \ePackage.\eClassifiers
      , list[EPackage] \eSubpackages = \ePackage.\eSubpackages
      , Id uid = \ePackage.uid
      , bool _inject = true)
  | ENamedElement(EClassifier \eClassifier
      , str \name = \eClassifier.\name
      , list[EAnnotation] \eAnnotations = \eClassifier.\eAnnotations
      , str \instanceClassName = \eClassifier.\instanceClassName
      , str \instanceTypeName = \eClassifier.\instanceTypeName
      , list[ETypeParameter] \eTypeParameters = \eClassifier.\eTypeParameters
      , Id uid = \eClassifier.uid
      , bool _inject = true)
  | ENamedElement(ETypeParameter \eTypeParameter
      , str \name = \eTypeParameter.\name
      , list[EAnnotation] \eAnnotations = \eTypeParameter.\eAnnotations
      , list[EGenericType] \eBounds = \eTypeParameter.\eBounds
      , Id uid = \eTypeParameter.uid
      , bool _inject = true)
  | ENamedElement(EEnumLiteral \eEnumLiteral
      , str \name = \eEnumLiteral.\name
      , list[EAnnotation] \eAnnotations = \eEnumLiteral.\eAnnotations
      , int \value = \eEnumLiteral.\value
      , str \literal = \eEnumLiteral.\literal
      , Id uid = \eEnumLiteral.uid
      , bool _inject = true)
  ;

data EGenericType
  = EGenericType(util::Maybe::Maybe[EGenericType] \eUpperBound = nothing()
      , list[EGenericType] \eTypeArguments = []
      , util::Maybe::Maybe[EGenericType] \eLowerBound = nothing()
      , lang::ecore::Refs::Ref[ETypeParameter] \eTypeParameter = null()
      , lang::ecore::Refs::Ref[EClassifier] \eClassifier = null()
      , lang::ecore::Refs::Id uid = noId())
  ;

data EOperation
  = EOperation(str \name = ""
      , bool \ordered = false
      , bool \unique = false
      , int \lowerBound = 0
      , int \upperBound = 0
      , list[EAnnotation] \eAnnotations = []
      , lang::ecore::Refs::Ref[EClassifier] \eType = null()
      , util::Maybe::Maybe[EGenericType] \eGenericType = nothing()
      , list[ETypeParameter] \eTypeParameters = []
      , list[EParameter] \eParameters = []
      , list[lang::ecore::Refs::Ref[EClassifier]] \eExceptions = []
      , list[EGenericType] \eGenericExceptions = []
      , lang::ecore::Refs::Id uid = noId())
  ;

data EPackage
  = EPackage(str \name = ""
      , list[EAnnotation] \eAnnotations = []
      , str \nsURI = ""
      , str \nsPrefix = ""
      , list[EClassifier] \eClassifiers = []
      , list[EPackage] \eSubpackages = []
      , lang::ecore::Refs::Id uid = noId())
  ;

data EFactory
  = EFactory(list[EAnnotation] \eAnnotations = []
      , lang::ecore::Refs::Id uid = noId())
  ;

data EModelElement
  = EModelElement(ENamedElement \eNamedElement
      , list[EAnnotation] \eAnnotations = \eNamedElement.\eAnnotations
      , str \name = \eNamedElement.\name
      , Id uid = \eNamedElement.uid
      , bool _inject = true)
  | EModelElement(EFactory \eFactory
      , list[EAnnotation] \eAnnotations = \eFactory.\eAnnotations
      , Id uid = \eFactory.uid
      , bool _inject = true)
  | EModelElement(EAnnotation \eAnnotation
      , list[EAnnotation] \eAnnotations = \eAnnotation.\eAnnotations
      , str \source = \eAnnotation.\source
      , list[EStringToStringMapEntry] \details = \eAnnotation.\details
      , list[EObject] \contents = \eAnnotation.\contents
      , list[lang::ecore::Refs::Ref[EObject]] \references = \eAnnotation.\references
      , Id uid = \eAnnotation.uid
      , bool _inject = true)
  ;

data EStringToStringMapEntry
  = EStringToStringMapEntry(str \key = ""
      , str \value = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data ETypedElement
  = ETypedElement(EOperation \eOperation
      , str \name = \eOperation.\name
      , bool \ordered = \eOperation.\ordered
      , bool \unique = \eOperation.\unique
      , int \lowerBound = \eOperation.\lowerBound
      , int \upperBound = \eOperation.\upperBound
      , list[EAnnotation] \eAnnotations = \eOperation.\eAnnotations
      , lang::ecore::Refs::Ref[EClassifier] \eType = \eOperation.\eType
      , EGenericType \eGenericType = \eOperation.\eGenericType
      , list[ETypeParameter] \eTypeParameters = \eOperation.\eTypeParameters
      , list[EParameter] \eParameters = \eOperation.\eParameters
      , list[lang::ecore::Refs::Ref[EClassifier]] \eExceptions = \eOperation.\eExceptions
      , list[EGenericType] \eGenericExceptions = \eOperation.\eGenericExceptions
      , Id uid = \eOperation.uid
      , bool _inject = true)
  | ETypedElement(EParameter \eParameter
      , str \name = \eParameter.\name
      , bool \ordered = \eParameter.\ordered
      , bool \unique = \eParameter.\unique
      , int \lowerBound = \eParameter.\lowerBound
      , int \upperBound = \eParameter.\upperBound
      , list[EAnnotation] \eAnnotations = \eParameter.\eAnnotations
      , lang::ecore::Refs::Ref[EClassifier] \eType = \eParameter.\eType
      , EGenericType \eGenericType = \eParameter.\eGenericType
      , Id uid = \eParameter.uid
      , bool _inject = true)
  | ETypedElement(EStructuralFeature \eStructuralFeature
      , str \name = \eStructuralFeature.\name
      , bool \ordered = \eStructuralFeature.\ordered
      , bool \unique = \eStructuralFeature.\unique
      , int \lowerBound = \eStructuralFeature.\lowerBound
      , int \upperBound = \eStructuralFeature.\upperBound
      , list[EAnnotation] \eAnnotations = \eStructuralFeature.\eAnnotations
      , lang::ecore::Refs::Ref[EClassifier] \eType = \eStructuralFeature.\eType
      , EGenericType \eGenericType = \eStructuralFeature.\eGenericType
      , bool \changeable = \eStructuralFeature.\changeable
      , bool \volatile = \eStructuralFeature.\volatile
      , bool \transient = \eStructuralFeature.\transient
      , str \defaultValueLiteral = \eStructuralFeature.\defaultValueLiteral
      , bool \unsettable = \eStructuralFeature.\unsettable
      , bool \derived = \eStructuralFeature.\derived
      , Id uid = \eStructuralFeature.uid
      , bool _inject = true)
  ;

data EAttribute
  = EAttribute(str \name = ""
      , bool \ordered = false
      , bool \unique = false
      , int \lowerBound = 0
      , int \upperBound = 0
      , bool \changeable = false
      , bool \volatile = false
      , bool \transient = false
      , str \defaultValueLiteral = ""
      , bool \unsettable = false
      , bool \derived = false
      , list[EAnnotation] \eAnnotations = []
      , lang::ecore::Refs::Ref[EClassifier] \eType = null()
      , util::Maybe::Maybe[EGenericType] \eGenericType = nothing()
      , bool \iD = false
      , lang::ecore::Refs::Id uid = noId())
  ;

data EAnnotation
  = EAnnotation(list[EAnnotation] \eAnnotations = []
      , str \source = ""
      , list[EStringToStringMapEntry] \details = []
      , list[EObject] \contents = []
      , list[lang::ecore::Refs::Ref[EObject]] \references = []
      , lang::ecore::Refs::Id uid = noId())
  ;

data EStructuralFeature
  = EStructuralFeature(EAttribute \eAttribute
      , str \name = \eAttribute.\name
      , bool \ordered = \eAttribute.\ordered
      , bool \unique = \eAttribute.\unique
      , int \lowerBound = \eAttribute.\lowerBound
      , int \upperBound = \eAttribute.\upperBound
      , bool \changeable = \eAttribute.\changeable
      , bool \volatile = \eAttribute.\volatile
      , bool \transient = \eAttribute.\transient
      , str \defaultValueLiteral = \eAttribute.\defaultValueLiteral
      , bool \unsettable = \eAttribute.\unsettable
      , bool \derived = \eAttribute.\derived
      , list[EAnnotation] \eAnnotations = \eAttribute.\eAnnotations
      , lang::ecore::Refs::Ref[EClassifier] \eType = \eAttribute.\eType
      , EGenericType \eGenericType = \eAttribute.\eGenericType
      , bool \iD = \eAttribute.\iD
      , Id uid = \eAttribute.uid
      , bool _inject = true)
  | EStructuralFeature(EReference \eReference
      , str \name = \eReference.\name
      , bool \ordered = \eReference.\ordered
      , bool \unique = \eReference.\unique
      , int \lowerBound = \eReference.\lowerBound
      , int \upperBound = \eReference.\upperBound
      , bool \changeable = \eReference.\changeable
      , bool \volatile = \eReference.\volatile
      , bool \transient = \eReference.\transient
      , str \defaultValueLiteral = \eReference.\defaultValueLiteral
      , bool \unsettable = \eReference.\unsettable
      , bool \derived = \eReference.\derived
      , list[EAnnotation] \eAnnotations = \eReference.\eAnnotations
      , lang::ecore::Refs::Ref[EClassifier] \eType = \eReference.\eType
      , EGenericType \eGenericType = \eReference.\eGenericType
      , bool \containment = \eReference.\containment
      , bool \resolveProxies = \eReference.\resolveProxies
      , lang::ecore::Refs::Ref[EReference] \eOpposite = \eReference.\eOpposite
      , list[lang::ecore::Refs::Ref[EAttribute]] \eKeys = \eReference.\eKeys
      , Id uid = \eReference.uid
      , bool _inject = true)
  ;

data EDataType
  = EDataType(str \name = ""
      , str \instanceClassName = ""
      , str \instanceTypeName = ""
      , list[EAnnotation] \eAnnotations = []
      , list[ETypeParameter] \eTypeParameters = []
      , bool \serializable = false
      , lang::ecore::Refs::Id uid = noId())
  | EDataType(EEnum \eEnum
      , str \name = \eEnum.\name
      , str \instanceClassName = \eEnum.\instanceClassName
      , str \instanceTypeName = \eEnum.\instanceTypeName
      , bool \serializable = \eEnum.\serializable
      , list[EAnnotation] \eAnnotations = \eEnum.\eAnnotations
      , list[ETypeParameter] \eTypeParameters = \eEnum.\eTypeParameters
      , list[EEnumLiteral] \eLiterals = \eEnum.\eLiterals
      , Id uid = \eEnum.uid
      , bool _inject = true)
  ;

data EEnumLiteral
  = EEnumLiteral(str \name = ""
      , list[EAnnotation] \eAnnotations = []
      , int \value = 0
      , str \literal = ""
      , lang::ecore::Refs::Id uid = noId())
  ;

data EClassifier
  = EClassifier(EDataType \eDataType
      , str \name = \eDataType.\name
      , str \instanceClassName = \eDataType.\instanceClassName
      , str \instanceTypeName = \eDataType.\instanceTypeName
      , list[EAnnotation] \eAnnotations = \eDataType.\eAnnotations
      , list[ETypeParameter] \eTypeParameters = \eDataType.\eTypeParameters
      , bool \serializable = \eDataType.\serializable
      , Id uid = \eDataType.uid
      , bool _inject = true)
  | EClassifier(EClass \eClass
      , str \name = \eClass.\name
      , str \instanceClassName = \eClass.\instanceClassName
      , str \instanceTypeName = \eClass.\instanceTypeName
      , list[EAnnotation] \eAnnotations = \eClass.\eAnnotations
      , list[ETypeParameter] \eTypeParameters = \eClass.\eTypeParameters
      , bool \abstract = \eClass.\abstract
      , bool \interface = \eClass.\interface
      , list[lang::ecore::Refs::Ref[EClass]] \eSuperTypes = \eClass.\eSuperTypes
      , list[EOperation] \eOperations = \eClass.\eOperations
      , list[EStructuralFeature] \eStructuralFeatures = \eClass.\eStructuralFeatures
      , list[EGenericType] \eGenericSuperTypes = \eClass.\eGenericSuperTypes
      , Id uid = \eClass.uid
      , bool _inject = true)
  ;

data EReference
  = EReference(str \name = ""
      , bool \ordered = false
      , bool \unique = false
      , int \lowerBound = 0
      , int \upperBound = 0
      , bool \changeable = false
      , bool \volatile = false
      , bool \transient = false
      , str \defaultValueLiteral = ""
      , bool \unsettable = false
      , bool \derived = false
      , list[EAnnotation] \eAnnotations = []
      , lang::ecore::Refs::Ref[EClassifier] \eType = null()
      , util::Maybe::Maybe[EGenericType] \eGenericType = nothing()
      , bool \containment = false
      , bool \resolveProxies = false
      , lang::ecore::Refs::Ref[EReference] \eOpposite = null()
      , list[lang::ecore::Refs::Ref[EAttribute]] \eKeys = []
      , lang::ecore::Refs::Id uid = noId())
  ;

data EEnum
  = EEnum(str \name = ""
      , str \instanceClassName = ""
      , str \instanceTypeName = ""
      , bool \serializable = false
      , list[EAnnotation] \eAnnotations = []
      , list[ETypeParameter] \eTypeParameters = []
      , list[EEnumLiteral] \eLiterals = []
      , lang::ecore::Refs::Id uid = noId())
  ;

data EParameter
  = EParameter(str \name = ""
      , bool \ordered = false
      , bool \unique = false
      , int \lowerBound = 0
      , int \upperBound = 0
      , list[EAnnotation] \eAnnotations = []
      , lang::ecore::Refs::Ref[EClassifier] \eType = null()
      , util::Maybe::Maybe[EGenericType] \eGenericType = nothing()
      , lang::ecore::Refs::Id uid = noId())
  ;

data EObject
  = EObject(lang::ecore::Refs::Id uid = noId())
  ;